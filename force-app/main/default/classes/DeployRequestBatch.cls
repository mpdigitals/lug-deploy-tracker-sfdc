/**
 * @description Batch Apex to retrieve DeployRequest records via Tooling API between two dates,
 * transform them into custom objects, and publish progress using Platform Events.
 * Handles component and test details if configured.
 * @author mpdigitals
 */
@SuppressWarnings('PMD.CognitiveComplexity')
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
    private Boolean streamingEnabled = false;
    private final DeployToolingClient client;
    private final DeploySetupWrapper cfg;

    private Map<Id, Map<String, Object>> raw = new Map<Id, Map<String, Object>>();
    private Integer total = 0;
    private Integer totalBatches = 0;
    private Integer batchesCompleted = 0;

    /**
     * @description Constructor with default DeploySetupWrapper from repository.
     * @param fromDate Start date for querying DeployRequest records.
     * @param toDate End date for querying DeployRequest records.
     */
    public DeployRequestBatch(Datetime fromDate, Datetime toDate, Boolean enableStreaming) {
        this(fromDate, toDate, DeploySetupRepository.getConfigWrapper(), true);
    }

    /**
     * @description Constructor with config and streaming flag.
     * @param fromDate Start of the query range.
     * @param toDate End of the query range.
     * @param config DeploySetupWrapper with configuration.
     * @param enableStreaming Whether to enable Platform Event tracking.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public DeployRequestBatch(Datetime fromDate, Datetime toDate, DeploySetupWrapper config, Boolean enableStreaming) {
        startDateTime = fromDate;
        endDateTime = toDate;
        cfg = config;
        streamingEnabled = enableStreaming;
        client = new DeployToolingClient(cfg.namedCredential, cfg.sessionId);
    }

    public Iterable<Id> start(Database.BatchableContext ctx) {
        DeployAccessValidator.enforceAccess();
        List<Id> ids = new List<Id>();
        String soql = buildQuery();
        HttpResponse res;

        try {
            res = client.query(soql);
            Integer code = res.getStatusCode();

            if (code >= 200 && code < 300) {
                ids = parseQueryResponse(res.getBody());
            } else {
                throw new System.CalloutException(res.getStatus() + ' - ' + res.getStatusCode());
            }

        } catch (Exception ex) {
            throw new System.CalloutException(ex.getMessage());
        }

        total = ids.size();

        if (total == 0) {
            return new List<Id>();
        }

        totalBatches = (Integer) Math.ceil((Decimal) total / DeployCoreUtils.getBatchSize());

        return ids;
    }

    public void execute(Database.BatchableContext ctx, List<Id> scope) {
        try {
            List<DeployResult__c> parents = mapParents(scope);
            Map<Id, DeployApiWrapper.DeployRequest> dtoMap = fetchDetails(parents);

            if (!parents.isEmpty()) {
                upsert parents DeployResult__c.Id__c;
            }

            upsertChildren(dtoMap, parents);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Batch execution error: ' + ex.getMessage());
        } finally {
            batchesCompleted++;
            publishProgress();
        }
    }

    public void finish(Database.BatchableContext ctx) {
        if (streamingEnabled) {
            EventBus.publish(new DeployProgress__e(Message__c = DeployConstants.MSG_SYNC_COMPLETE, Percentage__c = 100));
        }
    } 

    /**
     * @description Builds the SOQL query string to retrieve DeployRequest records from Tooling API,
     * applying the date filters and excluding intermediate statuses if configured.
     * @return A properly formatted SOQL string.
     */
    private String buildQuery() {
        String isoStart = toIso8601(startDateTime);
        String isoEnd = toIso8601(endDateTime);
        List<String> excluded = cfg.retrieveIntermediateStates ? new List<String>() : new List<String>{'InProgress', 'Pending', 'Canceling'};

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
     * @description Parses the JSON response from the Tooling API query to extract DeployRequest Ids
     * and store the raw record data for later mapping.
     * @param body Raw JSON response from the Tooling API.
     * @return A list of DeployRequest Ids extracted from the response.
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
     * @description Maps raw DeployRequest records into DeployResult__c SObjects
     * using the configured mapper logic.
     * @param scope List of DeployRequest Ids to map.
     * @return List of DeployResult__c SObjects to insert or update.
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
     * @description Fetches full deploy result details for each DeployRequest Id from the Tooling API
     * and deserializes them into strongly-typed DTOs.
     * @param parents List of parent DeployResult__c objects already mapped.
     * @return A map of DeployRequest Ids to corresponding DeployRequest DTOs.
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
                String patched = DeployCoreUtils.patchJsonKeys(res.getBody(), new Map<String, String>{
                    'time' => 'timeValue'
                });

                try {
                    DeployApiWrapper.DeployRequest dto = (DeployApiWrapper.DeployRequest) JSON.deserialize(patched, DeployApiWrapper.DeployRequest.class);

                    if (dto.id != null) {
                        result.put(Id.valueOf(dto.id), dto);
                        DeployResultMapper.appendCoverageWarnings(pr, dto);
                    }
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
     * @description Maps and upserts related child records (DeployResultComponent__c and DeployResultTest__c)
     * based on the deploy details retrieved from the Tooling API and the configuration flags.
     * @param dtoMap Map of DTOs indexed by DeployRequest Id.
     * @param parents List of corresponding parent DeployResult__c records.
     */
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
     * @description Retrieves the status of a batch job from AsyncApexJob using its Id.
     * Returns a map with status, number of errors, and any extended status message.
     * @param batchId The Id of the AsyncApexJob (batch job).
     * @return A map with keys: 'status', 'numberOfErrors', and 'extendedStatus'.
     */
    @AuraEnabled
    public static Map<String, String> getBatchStatus(Id batchId) {
        Map<String, String> result = new Map<String, String>{
            'status' => 'Unknown',
            'numberOfErrors' => '0',
            'extendedStatus' => ''
        };

        if (batchId == null) {
            result.put('extendedStatus', DeployConstants.ERR_BATCH_ID_REQUIRED);
            return result;
        }

        try {
            List<AsyncApexJob> jobs = [
                SELECT Status, NumberOfErrors, ExtendedStatus
                FROM AsyncApexJob
                WHERE Id = :batchId
                LIMIT 1
            ];

            if (!jobs.isEmpty()) {
                AsyncApexJob job = jobs[0];
                result.put('status', job.Status);
                result.put('numberOfErrors', String.valueOf(job.NumberOfErrors));
                result.put('extendedStatus', job.ExtendedStatus != null ? job.ExtendedStatus : '');
            } else {
                result.put('extendedStatus', DeployConstants.ERR_BATCH_NOT_FOUND);
            }
        } catch (Exception ex) {
            result.put('extendedStatus', DeployConstants.ERR_FETCHING_JOB_STATUS + ex.getMessage());
            System.debug(LoggingLevel.WARN, 'Failed to retrieve AsyncApexJob for ' + batchId + ': ' + ex.getMessage());
        }

        return result;
    }

    /**
     * @description Publishes Platform Events indicating synchronization progress based on the number of
     * batches completed, respecting the configured maximum number of events.
     */
    private void publishProgress() {
        if (!streamingEnabled || DeployConstants.MAX_PROGRESS_EVENTS <= 0) {
            return;
        }
        Integer step = Math.max(1, totalBatches / DeployConstants.MAX_PROGRESS_EVENTS);
        Boolean isFinal = batchesCompleted >= totalBatches;
        Boolean isStep = Math.mod(batchesCompleted, step) == 0;

        if (!isFinal && !isStep) {
            return;
        }

        Integer pct = totalBatches == 0
            ? 100
            : Math.min(100, (batchesCompleted * 100) / totalBatches);

        EventBus.publish(new DeployProgress__e(
            Message__c = DeployConstants.MSG_SYNC_PROGRESS,
            Percentage__c = pct
        ));
    }

    /**
     * @description Converts a Datetime to an ISO 8601 GMT string format for use in Tooling API SOQL queries.
     * @param dt The Datetime value to convert.
     * @return A string in ISO 8601 format (e.g., '2024-06-01T00:00:00Z').
     */
    private static String toIso8601(Datetime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}