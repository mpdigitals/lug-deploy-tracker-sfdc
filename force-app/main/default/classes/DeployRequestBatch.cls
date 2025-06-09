/**
 * @description Batch job that queries DeployRequest records through the Tooling API,
 * converts them to custom-object data and publishes incremental progress.
 * Only patches the 'time' field in RunTestResult to match the wrapper format.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployRequestBatch implements Database.Batchable<Id>, Database.AllowsCallouts, Database.Stateful {

    private static final List<String> SOQL_FIELDS = new List<String>{
        'Id',
        'CreatedDate',
        'CreatedById',
        'CreatedBy.Name',
        'LastModifiedById',
        'NumberComponentsDeployed',
        'NumberComponentErrors',
        'NumberComponentsTotal',
        'NumberTestsCompleted',
        'NumberTestErrors',
        'NumberTestsTotal',
        'CheckOnly',
        'IgnoreWarnings',
        'RollbackOnError',
        'Type',
        'StartDate',
        'CompletedDate',
        'CanceledById',
        'CanceledBy.Name',
        'RunTestsEnabled',
        'ChangeSetName',
        'ErrorStatusCode',
        'Status',
        'StateDetail',
        'ErrorMessage',
        'AllowMissingFiles',
        'AutoUpdatePackage',
        'PurgeOnDelete',
        'SinglePackage',
        'TestLevel'
    };

    private final Datetime startDateTime;
    private final Datetime endDateTime;
    private final DeployToolingClient client;
    private final DeploySetupWrapper cfg;

    private Map<Id, Map<String, Object>> raw = new Map<Id, Map<String, Object>>();
    private Integer total = 0;
    private Integer processed = 0;
    private Integer step = 0;

    /**
     * @description Constructor with default DeploySetupWrapper from repository.
     * @param fromDate Start date for querying DeployRequest records.
     * @param toDate End date for querying DeployRequest records.
     */
    public DeployRequestBatch(Datetime fromDate, Datetime toDate) {
        this(fromDate, toDate, DeploySetupRepository.getConfigWrapper());
    }

    /**
     * @description Constructor with provided DeploySetupWrapper.
     * @param fromDate Start date for querying DeployRequest records.
     * @param toDate End date for querying DeployRequest records.
     * @param config DeploySetupWrapper configuration.
     */
    public DeployRequestBatch(Datetime fromDate, Datetime toDate, DeploySetupWrapper config) {
        startDateTime = fromDate;
        endDateTime = toDate;
        cfg = config;
        client = new DeployToolingClient(config.namedCredential);
    }

    /**
     * @description Prepares the list of DeployRequest Ids to process in the batch.
     * @param ctx Database batch context.
     * @return Iterable of DeployRequest Ids.
     */
    public Iterable<Id> start(Database.BatchableContext ctx) {
        DeployAccessValidator.enforceAccess();

        List<Id> ids = new List<Id>();
        String soql = buildQuery();
        HttpResponse res;

        try {
            res = client.query(soql);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Query error: ' + ex.getMessage());
            return ids;
        }

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            ids = parseQueryResponse(res.getBody());
        } else {
            System.debug(LoggingLevel.ERROR, 'Tooling API query failed ' + res.getStatus() + ': ' + res.getBody());
        }

        total = ids.size();
        step = total > 0 ? Math.max(1, total / DeployConstants.MAX_PROGRESS_EVENTS) : 1;
        return ids;
    }

    /**
     * @description Executes the batch processing logic for each scope of DeployRequest Ids.
     * @param ctx Database batch context.
     * @param scope List of DeployRequest Ids to process in this execution.
     */
    public void execute(Database.BatchableContext ctx, List<Id> scope) {
        List<DeployResult__c> parents = mapParents(scope);
        Map<Id, DeployApiWrapper.DeployRequest> dtoMap = fetchDetails(parents);

        if (!parents.isEmpty()) {
            upsert parents Id__c;
        }

        upsertChildren(dtoMap, parents);

        processed += scope.size();
        publishProgress();
    }

    /**
     * @description Publishes a final progress event when the batch finishes.
     * @param ctx Database batch context.
     */
    public void finish(Database.BatchableContext ctx) {
        EventBus.publish(new DeployProgress__e(Message__c = 'Sync complete', Percentage__c = 100));
    }

    /**
     * @description Builds the SOQL query to fetch DeployRequest records.
     * @return SOQL query string.
     */
    private String buildQuery() {
        String isoStart = toIso8601(startDateTime);
        String isoEnd = toIso8601(endDateTime);

        List<String> excluded = cfg.retrieveIntermediateStates
            ? new List<String>()
            : new List<String>{ 'InProgress', 'Pending', 'Canceling' };

        String query = 'SELECT ' + String.join(SOQL_FIELDS, ',');
        query += ' FROM DeployRequest';
        query += ' WHERE CompletedDate >= ' + String.escapeSingleQuotes(isoStart);
        query += ' AND CompletedDate <= ' + String.escapeSingleQuotes(isoEnd);

        if (!excluded.isEmpty()) {
            List<String> safeStatuses = new List<String>();
            for (String status : excluded) {
                safeStatuses.add('\'' + String.escapeSingleQuotes(status) + '\'');
            }
            query += ' AND Status NOT IN (' + String.join(safeStatuses, ',') + ')';
        }

        return query;
    }

    /**
     * @description Parses the Tooling API response and extracts DeployRequest Ids.
     * @param body JSON response body.
     * @return List of DeployRequest Ids.
     */
    private List<Id> parseQueryResponse(String body) {
        List<Id> ids = new List<Id>();
        Map<String, Object> p = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> records = (List<Object>) p.get('records');
        if (records != null && !records.isEmpty()) {
            for (Object o : records) {
                Map<String, Object> row = (Map<String, Object>) o;
                Id idVal = (Id) row.get('Id');
                raw.put(idVal, row);
                ids.add(idVal);
            }
        }
        return ids;
    }

    /**
     * @description Maps DeployRequest raw records to DeployResult__c parent records.
     * @param scope List of DeployRequest Ids.
     * @return List of DeployResult__c records.
     */
    private List<DeployResult__c> mapParents(List<Id> scope) {
        List<DeployResult__c> out = new List<DeployResult__c>();
        for (Id idVal : scope) {
            Map<String, Object> r = raw.get(idVal);
            if (r != null) {
                out.add(DeployResultMapper.mapResult(r));
            }
        }
        return out;
    }

    /**
     * @description Fetches detailed DeployRequest data from the Tooling API.
     * @param parents List of DeployResult__c parent records.
     * @return Map of DeployRequest Id to DeployRequest wrapper.
     */
    private Map<Id, DeployApiWrapper.DeployRequest> fetchDetails(List<DeployResult__c> parents) {
        Map<Id, DeployApiWrapper.DeployRequest> result = new Map<Id, DeployApiWrapper.DeployRequest>();
        for (DeployResult__c pr : parents) {
            HttpResponse res;
            try {
                res = client.fetchDeployResult(pr.Id__c);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Callout error ' + pr.Id__c + ': ' + ex.getMessage());
                continue;
            }
            Integer code = res.getStatusCode();
            if (code >= 200 && code < 300) {
                String patched = DeployCoreUtils.patchJsonKeys(res.getBody(), new Map<String, String>{ 'time' => 'timeValue' });
                try {
                    DeployApiWrapper.DeployRequest dto = (DeployApiWrapper.DeployRequest) JSON.deserialize(patched, DeployApiWrapper.DeployRequest.class);
                    result.put(Id.valueOf(dto.id), dto);
                    DeployResultMapper.appendCoverageWarnings(pr, dto);
                } catch (Exception je) {
                    System.debug(LoggingLevel.ERROR, 'JSON parse error ' + pr.Id__c + ': ' + je.getMessage());
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'Detail callout failed ' + pr.Id__c + ' status ' + code);
            }
        }
        return result;
    }

    /**
     * @description Upserts child DeployResultComponent__c and DeployResultTest__c records.
     * @param dtoMap Map of DeployRequest Id to DeployRequest wrapper.
     * @param parents List of DeployResult__c parent records.
     */
    @SuppressWarnings('PMD.CognitiveComplexity')
    private void upsertChildren(Map<Id, DeployApiWrapper.DeployRequest> dtoMap, List<DeployResult__c> parents) {
        Map<String, DeployResultComponent__c> comp = new Map<String, DeployResultComponent__c>();
        Map<String, DeployResultTest__c> test = new Map<String, DeployResultTest__c>();
        for (DeployResult__c p : parents) {
            DeployApiWrapper.DeployRequest dto = dtoMap.get(p.Id__c);
            if (dto == null || dto.deployResult == null || dto.deployResult.details == null) {
                continue;
            }
            if (cfg.retrieveComponents && dto.deployResult.details.allComponentMessages != null) {
                for (DeployResultComponent__c c : DeployResultComponentMapper.mapComponents(dto, p.Id)) {
                    comp.put(c.ExtId__c, c);
                }
            }
            if (cfg.retrieveTests && dto.deployResult.details.runTestResult != null) {
                for (DeployResultTest__c t : DeployResultTestMapper.mapResultTests(dto, p.Id)) {
                    test.put(t.ExtId__c, t);
                }
            }
        }
        if (!comp.isEmpty()) {
            upsert comp.values() ExtId__c;
        }
        if (!test.isEmpty()) {
            upsert test.values() ExtId__c;
        }
    }

    /**
     * @description Publishes a progress event during batch execution.
     */
    private void publishProgress() {
        Integer pct = total == 0 ? 100 : Math.min(100, (processed * 100) / total);
        EventBus.publish(new DeployProgress__e(Message__c = 'Sync progress', Percentage__c = pct));
    }

    /**
     * @description Converts a Datetime to ISO 8601 GMT format.
     * @param dt Datetime to format.
     * @return ISO 8601 formatted string.
     */
    private static String toIso8601(Datetime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}