/**
 * @description Implements HttpCalloutMock to simulate Tooling API responses using Static Resources. Used in test classes to mock API responses for deploy-related queries.
 * @author develop@mpdigitals.com
 */
@IsTest
public class DeployToolingApiMock implements HttpCalloutMock {

    /**
     * @description Returns a mocked HttpResponse with JSON body loaded from a Static Resource.
     * @param req The incoming HttpRequest.
     * @return The simulated HttpResponse with body content based on the endpoint.
     */
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);

        String staticName = req.getEndpoint().contains('/query')
            ? 'deployToolingApiQuery'
            : 'deployToolingApiResponse';

        StaticResource sr = [
            SELECT Body FROM StaticResource WHERE Name = :staticName LIMIT 1
        ];

        String json = sr.Body.toString();
        res.setBody(json);

        return res;
    }
}