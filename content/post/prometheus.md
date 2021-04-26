Prometheus is a monitoring system
It does several things for metrics:

https://www.youtube.com/watch?v=sHKWD8XnmmY

* collects metrics
* storing metrics
* querying metrics
* alerting on metrics

The origin has been developed by SunClound 2012.
At 2015 it has been become Prometheus.

If we compare Prometheus to more traditional systems like Nagios or Zabbix,
the rely on external checks for the applications they want to monitor.
Prometheus expects that the applications we want to monitor are observable from the outside instead of being black boxes, they need to expose their state or something that will tell us how they behave. This process is what we call in the monitoring world as "Instrumentation".

When we say "metric instrumentation" we can think of events as logs, events, traces and other forms which are interesting to investigate.

# How Prometheus works
We have the prometheus Server. Its job is to store and collect metrics.
We have also the systems we want to monitor.
Prometheus is a pull-based system, in a sense that is doesn't expect an agent to be pushing the metrics, but it will take the initiative to communicate with the agent by itself.
It's doing so by HTTP/HTTPS requests to specific endpoints, which are called "metrics endpoints".
It communicated every X amount of time, which is called "regular interval". So every X minutes it communicates with the systems and scrapes their metrics from the applications we want to monitor.

# How can an application expose its metrics?

There are two options for that:

1. Using a the Prometheus client library (e.g. Python, Java, C++, Ruby). This library will offeran API where we are going to use to manipulate the metrics.
   To create them, to increment them, or to set them into a certain value. And finally the finally will allows us to expose those metrics to Promehtues service via HTTP.
   We highly recommend this way. But if you have written the app years ago and you don't want to modify this, then you can use the second options.

2. Run an exporter. This is a process running next to our application. It will be in charge of converting the internal metric format to something that Prometheus can understand.
   You need to maintain the exporter side by side with your application.

# How the Prometheus data format looks like

this is based on Timeseries data model, which is a reference to something we want to measure.

```
http_requests_total{code="200",method="GET",job"app",instance="foo:8000"}
```

This has two parts:

The name of the metric: http_requests_total
The labels: {code="200",method="GET",job"app",instance="foo:8000"}

The labels has a key and value. The goal is to filter and aggregate the timeseries as we wish.

