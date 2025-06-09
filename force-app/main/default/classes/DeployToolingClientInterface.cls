/**
 * @description Interface to abstract Tooling API callouts for querying and retrieving deploy results.
 * @author develop@mpdigitals.com
 */
public interface DeployToolingClientInterface {

    /**
     * @description Executes a SOQL query via Tooling API.
     * @param soql A valid SOQL query string.
     * @return The HttpResponse returned from the API.
     */
    HttpResponse query(String soql);

    /**
     * @description Retrieves the deploy result for a given DeployRequest Id.
     * @param deployRequestId The Id of the DeployRequest.
     * @return The HttpResponse containing deploy result details.
     */
    HttpResponse fetchDeployResult(Id deployRequestId);
}