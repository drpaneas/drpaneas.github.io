A valid Telemeter v2 client must package the time series it wishes to send into a Prometheus WriteRequest.
This WriteRequest must use protocol buffer encoding, be compressed using Snappy, and sent via an HTTP POST request.
In order for the request to be accepted, the client must include a bearer token in the Authorization HTTP header consisting of a base64 encoded JSON object with two fields:
* cluster_id: a string holding the cluster’s unique ID; and
* authorization_token: a string with the cluster’s pull secret auth token

```
-endpoint-read string  : the endpoint to which to make query requests.
-endpoint-type string  : the endpoint type.Options: logs, metrics
```

Prometheus client: https://github.com/prometheus/client_golang

