+++
categories = ["kubernetes"]
date = "2020-03-15T03:29:35+01:00"
tags = ["kubernetes", "controllers", "golang", "google", "api"]
title = "Write a Google GCP client with Go"

+++

In this article I will explain the mechanics of writing a client for Google GCP, pretty similar like `gcloud`.
The purpose is to not write a full-featured client (that would make no sense, since you can use `gcloud` already) but to learn the how to communicate with Google's GCP API using Go.
Such a `pkg` can be useful in small projects where you need to talk to Google GCP API, like the [OpenShift's GCP Operator](https://github.com/openshift/gcp-project-operator).
Writing a Kubernetes operator for Google GCP, you need to teach your controllers to do basic CRUD (Create, Read, Update, Destroy) operations on the Google cloud.
Having an individual project (like this one) it make your developer-life easier, since for testing your communication with Google, you wont have to setup any environment or CRDs.


## Create the struct

First of all we need to create the struct that represents the type of our client.
Since we are going to interact with Google GCP cloud, pick a relevant name, for example we are going to name it `GoogleGCPClient`.

Later we have to read how to setup authentication and authorization.
> Authentication identifies who you are, and authorization determines what you can do.
Grab a coffee and [start reading this article](https://cloud.google.com/docs/authentication/production#obtaining_and_providing_service_account_credentials_manually)

### Create A Service Account

1. In the Cloud Console, go to the [Create service account key](https://console.cloud.google.com/apis/credentials/serviceaccountkey) page.

2. From the **Service Account** list, select **New service account**

3. In the **Service account name** field, enter a name.

4. From the **Role** list, select **Project > Owner**.

5. Click **Create**. A JSON file that contains your key downloads to your computer.

I have saved this file to my `$HOME` directory and named it `mypersonalgcpjsonkey.json`.

### Pass the credentials

```go
// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID, replace it with yours
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file, replace it with yours
```

### Client for Cloud Resource Manager

The package [cloudresourcemanager](google.golang.org/api/cloudresourcemanager/v1) provides access to the (Cloud Resource Manager API)[https://cloud.google.com/resource-manager/docs].
It is used to create, read, and update metadata for Google Cloud Platform resource containers.

```go
package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/option"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

func main() {
	ctx := context.Background()
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudresourcemanagerService.BasePath)
}
```

As a verification that our credentials work, this will print the following:

```
2020/03/12 23:38:57 https://cloudresourcemanager.googleapis.com/
```

### Client for the IAM

IAM lets admins to authorize **who** can take **actions** on **specific resources**.
The **who** part is obviously our ServiceAccount.
The **actions** part, is a primitive role, the project's Owner.
For that we will use the [iam](google.golang.org/api/iam/v1) package that provides access to the [Identity and Access Management (IAM) API](https://cloud.google.com/iam/).

```go
package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

func main() {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudresourcemanagerService.BasePath)

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(iamService.BasePath)
}
```

For verification purposes this is going to print:

```
2020/03/12 23:45:45 https://cloudresourcemanager.googleapis.com/
2020/03/12 23:45:45 https://iam.googleapis.com/
```

### Client for Service Infrastructure Management

[Service Infrastructure](https://cloud.google.com/service-infrastructure/docs) is Google's foundational platform for creating, managing, and consuming APIs and services.
It is used by Google APIs, Google Cloud APIs, and Cloud Endpoints. Service Infrastructure provides a wide range of features to service consumers and service producers, including authentication, authorization, auditing, rate limiting, billing, logging, and monitoring.

We are going to use the [servicemanagement](google.golang.org/api/servicemanagement/v1) package which provides access to the Service Management API.

```go
package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

func main() {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudresourcemanagerService.BasePath)

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(iamService.BasePath)

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(servicemanagementService.BasePath)
}
```

For verification:

```
2020/03/12 23:53:11 https://cloudresourcemanager.googleapis.com/
2020/03/12 23:53:11 https://iam.googleapis.com/
2020/03/12 23:53:11 https://servicemanagement.googleapis.com/
```

### Client for Cloud Billing

A [Cloud Billing](https://cloud.google.com/billing/docs) account defines who pays for a given set of Google Cloud resources, and you can link the account to one or more projects.
Your project usage is charged to the linked Cloud Billing account.
To use Google Cloud services, you must have a **valid** Cloud Billing account linked to your project.
You must have a valid Cloud Billing account even if you are in your free trial period or if you choose to only use Google Cloud resources that are covered by the Always Free program.

We will use the [cloudbilling](google.golang.org/api/cloudbilling/v1) package which provides access to the Cloud Billing API.

```go
package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

func main() {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudresourcemanagerService.BasePath)

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(iamService.BasePath)

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(servicemanagementService.BasePath)

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudbillingService.BasePath)
}
```

### Client for Cloud DNS

The Google Cloud DNS is reliable, resilient and it provides low-latency DNS serving from Google's worldwide network.
You can publish your domain names by using Google's infrastructure for production-quality, high-volume DNS services.
Google's global network of anycast name servers provide reliable, low-latency, authoritative name lookups for your domains from anywhere in the world.

For that we will use the [dns](google.golang.org/api/dns/v1) package.

```go
package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

func main() {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudresourcemanagerService.BasePath)

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(iamService.BasePath)

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(servicemanagementService.BasePath)

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(cloudbillingService.BasePath)

	// Client for Google Cloud DNS API
	dnsService, err := dns.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(dnsService.BasePath)
}
```

The output will be:

```
2020/03/13 00:30:17 https://cloudresourcemanager.googleapis.com/
2020/03/13 00:30:17 https://iam.googleapis.com/
2020/03/13 00:30:17 https://servicemanagement.googleapis.com/
2020/03/13 00:30:17 https://cloudbilling.googleapis.com/
2020/03/13 00:30:17 https://dns.googleapis.com/dns/v1/projects/
```

## Create a wrapper for all of those clients

Our intention is to make the code cleaner and more concise.
For that we will group all of those different clients into an object.
Later we will create an instance of this object, so we can use it.

### Create the struct

We will create a new client object for interacting with Google Cloud:

```go
// GoogleCloudClient is a generic wrapper for talking with individual services inside Google Cloud
// such as Cloud Resource Manager, IAM, Services, Billing and DNS
type GoogleCloudClient struct {
	// Structs from Google library
	Resource *cloudresourcemanager.Service
	IAM      *iam.Service
	Service  *servicemanagement.APIService
	Billing  *cloudbilling.APIService
	DNS      *dns.Service

	// Required user input
	ProjectID string
	JSONPath  string
}
```

### Create an instance

The preferred method is to use a factory function in order to ensure that the new instance of `GoogleCloudClient` struct will be constructed with the required arguments.

The only input from the user is going to be the `ProjectID` and the `JSONPath`.
We want to give those arguments and take back a ready-to-use instance of `GoogleCloudClient`.
To be more precise, we will return a **pointer** to the `GoogleCloudClient` instance.

```go
// NewGoogleCloudClient returns a pointer to the `GoogleCloudClient` instance
func NewGoogleCloudClient(projectID string, json string) (*GoogleCloudClient, error) {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with Cloud Resource Manager Service: %v", err)
	}

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the IAM Service: %v", err)
	}

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Service Management Service: %v", err)
	}

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud Billing Account: %v", err)
	}

	// Client for Google Cloud DNS API
	dnsService, err := dns.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud DNS: %v", err)
	}

	return &GoogleCloudClient{
		Resource:  cloudresourcemanagerService,
		IAM:       iamService,
		Service:   servicemanagementService,
		Billing:   cloudbillingService,
		DNS:       dnsService,
		ProjectID: projectID,
		JSONPath:  json,
	}, nil
}
```

### Use the instance

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

// GoogleCloudClient is a generic wrapper for talking with individual services inside Google Cloud
// such as Cloud Resource Manager, IAM, Services, Billing and DNS
type GoogleCloudClient struct {
	// Structs from Google library
	Resource *cloudresourcemanager.Service
	IAM      *iam.Service
	Service  *servicemanagement.APIService
	Billing  *cloudbilling.APIService
	DNS      *dns.Service

	// Required user input
	ProjectID string
	JSONPath  string
}

// NewGoogleCloudClient returns a pointer to the `GoogleCloudClient` instance
func NewGoogleCloudClient(projectID string, json string) (*GoogleCloudClient, error) {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with Cloud Resource Manager Service: %v", err)
	}

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the IAM Service: %v", err)
	}

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Service Management Service: %v", err)
	}

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud Billing Account: %v", err)
	}

	// Client for Google Cloud DNS API
	dnsService, err := dns.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud DNS: %v", err)
	}

	return &GoogleCloudClient{
		Resource:  cloudresourcemanagerService,
		IAM:       iamService,
		Service:   servicemanagementService,
		Billing:   cloudbillingService,
		DNS:       dnsService,
		ProjectID: projectID,
		JSONPath:  json,
	}, nil
}

func main() {
	gcpClient, err := NewGoogleCloudClient(projectID, jsonPath)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(gcpClient.Resource.BasePath)
	fmt.Println(gcpClient.IAM.BasePath)
	fmt.Println(gcpClient.Service.BasePath)
	fmt.Println(gcpClient.Billing.BasePath)
	fmt.Println(gcpClient.DNS.BasePath)
}
```

The output for verification should be:

```
https://cloudresourcemanager.googleapis.com/
https://iam.googleapis.com/
https://servicemanagement.googleapis.com/
https://cloudbilling.googleapis.com/
https://dns.googleapis.com/dns/v1/projects/
```

## Do stuff with the Cloud Resource Manager

That it is.
Now you have established a secure connection with Google GCP and you can start using its API.
I will show you some basic examples, so you can get an idea.

### List Projects

Read: [Method: projects.list](https://cloud.google.com/resource-manager/reference/rest/v1/projects/list)

You need to have Cloud Resource Manager API in your project. To do that:

1. Go to the webpage that says [Cloud Resource Manager API](https://console.developers.google.com/apis/library/cloudresourcemanager.googleapis.com)
2. Click **Enable**.
3. Wait a little bit to get it enabled.

We will use the function `*cloudresourcemanager.Service.Projects.List().Do()` which returns two things:

* `*cloudresourcemanager.ListProjectsResponse`
* `error`

So what is this `*cloudresourcemanager.ListProjectsResponse`?
This is a pointer to a struct `ListProjectsResponse` that looks like this:

```go
type ListProjectsResponse struct {
	// Pagination tokens have a limited lifetime.
	NextPageToken string `json:"nextPageToken,omitempty"`

	// Projects: The list of Projects that matched the list filter. This list can be paginated.
	Projects []*Project `json:"projects,omitempty"`

	// ServerResponse contains the HTTP response code and headers from the server.
	googleapi.ServerResponse `json:"-"`

	/// and others
```

We are interested into the `Projects` field which is a list of another struct called `Project` which looks like this:

```go
type Project struct {
	CreateTime string `json:"createTime,omitempty"`
	Labels map[string]string `json:"labels,omitempty"`
	LifecycleState string `json:"lifecycleState,omitempty"`
	Name string `json:"name,omitempty"`
	Parent *ResourceId `json:"parent,omitempty"`
	ProjectId string `json:"projectId,omitempty"`
	ProjectNumber int64 `json:"projectNumber,omitempty,string"`
	googleapi.ServerResponse `json:"-"`
	ForceSendFields []string `json:"-"`
	NullFields []string `json:"-"`
}
```

To keep it simple,  we are interested particularly for the `Name` and the `ProjectID`.

```go
	// Fetch ListProjectsResponse
	projectsList, err := gcpClient.Resource.Projects.List().Do()
	if err != nil {
		log.Fatal(err)
	}
	// From every Project of the ListProjectsResponse print the Name and the ProjectID
	for _, value := range projectsList.Projects {
		fmt.Printf("Project Name: %s\tProjectID: %s\r\n", value.Name, value.ProjectId)
	}
```

The output is:

```
Project Name: My First Project  ProjectID: hidden-howl-252922
```

#### Make a method

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

// GoogleCloudClient is a generic wrapper for talking with individual services inside Google Cloud
// such as Cloud Resource Manager, IAM, Services, Billing and DNS
type GoogleCloudClient struct {
	// Structs from Google library
	Resource *cloudresourcemanager.Service
	IAM      *iam.Service
	Service  *servicemanagement.APIService
	Billing  *cloudbilling.APIService
	DNS      *dns.Service

	// Required user input
	ProjectID string
	JSONPath  string
}

// NewGoogleCloudClient returns a pointer to the `GoogleCloudClient` instance
func NewGoogleCloudClient(projectID string, json string) (*GoogleCloudClient, error) {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with Cloud Resource Manager Service: %v", err)
	}

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the IAM Service: %v", err)
	}

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Service Management Service: %v", err)
	}

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud Billing Account: %v", err)
	}

	// Client for Google Cloud DNS API
	dnsService, err := dns.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud DNS: %v", err)
	}

	return &GoogleCloudClient{
		Resource:  cloudresourcemanagerService,
		IAM:       iamService,
		Service:   servicemanagementService,
		Billing:   cloudbillingService,
		DNS:       dnsService,
		ProjectID: projectID,
		JSONPath:  json,
	}, nil
}

// ListProjects lists the Projects of a GCP service account and returns an error
func (c *GoogleCloudClient) ListProjects() (*cloudresourcemanager.ListProjectsResponse, error) {
	projectsList, err := c.Resource.Projects.List().Do()
	if err != nil {
		return nil, err
	}
	return projectsList, nil
}

func main() {
	gcpClient, err := NewGoogleCloudClient(projectID, jsonPath)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(gcpClient.Resource.BasePath)
	fmt.Println(gcpClient.IAM.BasePath)
	fmt.Println(gcpClient.Service.BasePath)
	fmt.Println(gcpClient.Billing.BasePath)
	fmt.Println(gcpClient.DNS.BasePath)

	resp, err := gcpClient.ListProjects()
	if err != nil {
		log.Fatal(err)
	}
	for _, project := range resp.Projects {
		fmt.Printf("Project Name: %s\tProjectID: %s\r\n", project.Name, project.ProjectId)
	}

}
```

Output:
```
Project Name: My First Project  ProjectID: hidden-howl-252922
```

#### Get a Project

Now that you can list the projects, you can also `get` one.
Storing a project into a variable, you can later use the `.` to access attributed of that project.

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

// GoogleCloudClient is a generic wrapper for talking with individual services inside Google Cloud
// such as Cloud Resource Manager, IAM, Services, Billing and DNS
type GoogleCloudClient struct {
	// Structs from Google library
	Resource *cloudresourcemanager.Service
	IAM      *iam.Service
	Service  *servicemanagement.APIService
	Billing  *cloudbilling.APIService
	DNS      *dns.Service

	// Required user input
	ProjectID string
	JSONPath  string
}

// NewGoogleCloudClient returns a pointer to the `GoogleCloudClient` instance
func NewGoogleCloudClient(projectID string, json string) (*GoogleCloudClient, error) {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with Cloud Resource Manager Service: %v", err)
	}

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the IAM Service: %v", err)
	}

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Service Management Service: %v", err)
	}

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud Billing Account: %v", err)
	}

	// Client for Google Cloud DNS API
	dnsService, err := dns.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud DNS: %v", err)
	}

	return &GoogleCloudClient{
		Resource:  cloudresourcemanagerService,
		IAM:       iamService,
		Service:   servicemanagementService,
		Billing:   cloudbillingService,
		DNS:       dnsService,
		ProjectID: projectID,
		JSONPath:  json,
	}, nil
}

// ListProjects lists the Projects of a GCP service account and returns an error
func (c *GoogleCloudClient) ListProjects() (*cloudresourcemanager.ListProjectsResponse, error) {
	projectsList, err := c.Resource.Projects.List().Do()
	if err != nil {
		return nil, err
	}
	return projectsList, nil
}

// GetProject returns a project from GCP
func (c *GoogleCloudClient) GetProject(projectID string) (*cloudresourcemanager.Project, error) {
	project, err := c.Resource.Projects.Get(projectID).Do()
	if err != nil {
		return nil, err
	}
	return project, nil
}

func main() {
	gcpClient, err := NewGoogleCloudClient(projectID, jsonPath)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(gcpClient.Resource.BasePath)
	fmt.Println(gcpClient.IAM.BasePath)
	fmt.Println(gcpClient.Service.BasePath)
	fmt.Println(gcpClient.Billing.BasePath)
	fmt.Println(gcpClient.DNS.BasePath)

	resp, err := gcpClient.ListProjects()
	if err != nil {
		log.Fatal(err)
	}
	for _, project := range resp.Projects {
		fmt.Printf("Project Name: %s\tProjectID: %s\r\n", project.Name, project.ProjectId)
	}

	// gcpClient.Resource.Projects.Delete("hidden-howl-252922")
	resp1, err := gcpClient.GetProject("hidden-howl-252922")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(resp1.Name)

}
```

### Delete a Project

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicemanagement/v1"
)

// Credentials
var projectID = "hidden-howl-252922"                                         // Your ProjectID
var jsonPath = filepath.Join(os.Getenv("HOME"), "mypersonalgcpjsonkey.json") // path to your JSON file

// GoogleCloudClient is a generic wrapper for talking with individual services inside Google Cloud
// such as Cloud Resource Manager, IAM, Services, Billing and DNS
type GoogleCloudClient struct {
	// Structs from Google library
	Resource *cloudresourcemanager.Service
	IAM      *iam.Service
	Service  *servicemanagement.APIService
	Billing  *cloudbilling.APIService
	DNS      *dns.Service

	// Required user input
	ProjectID string
	JSONPath  string
}

// NewGoogleCloudClient returns a pointer to the `GoogleCloudClient` instance
func NewGoogleCloudClient(projectID string, json string) (*GoogleCloudClient, error) {
	ctx := context.Background()

	// Client for Cloud Resource Manager
	cloudresourcemanagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with Cloud Resource Manager Service: %v", err)
	}

	// Client for IAM
	iamService, err := iam.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the IAM Service: %v", err)
	}

	// Client for Service Infrastructure Manager
	servicemanagementService, err := servicemanagement.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Service Management Service: %v", err)
	}

	// Client for Cloud Billing
	cloudbillingService, err := cloudbilling.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud Billing Account: %v", err)
	}

	// Client for Google Cloud DNS API
	dnsService, err := dns.NewService(ctx, option.WithCredentialsFile(jsonPath))
	if err != nil {
		return nil, fmt.Errorf("Error with the Cloud DNS: %v", err)
	}

	return &GoogleCloudClient{
		Resource:  cloudresourcemanagerService,
		IAM:       iamService,
		Service:   servicemanagementService,
		Billing:   cloudbillingService,
		DNS:       dnsService,
		ProjectID: projectID,
		JSONPath:  json,
	}, nil
}

// ListProjects lists the Projects of a GCP service account and returns an error
func (c *GoogleCloudClient) ListProjects() (*cloudresourcemanager.ListProjectsResponse, error) {
	projectsList, err := c.Resource.Projects.List().Do()
	if err != nil {
		return nil, err
	}
	return projectsList, nil
}

// GetProject returns a project from GCP
func (c *GoogleCloudClient) GetProject(projectID string) (*cloudresourcemanager.Project, error) {
	project, err := c.Resource.Projects.Get(projectID).Do()
	if err != nil {
		return nil, err
	}
	return project, nil
}

// DeleteProject deletes a project from GCP
func (c *GoogleCloudClient) DeleteProject(projectID string) (*cloudresourcemanager.Empty, error) {
	project, err := c.Resource.Projects.Delete(projectID).Do()
	if err != nil {
		return nil, err
	}
	return project, nil
}

func main() {
	gcpClient, err := NewGoogleCloudClient(projectID, jsonPath)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(gcpClient.Resource.BasePath)
	fmt.Println(gcpClient.IAM.BasePath)
	fmt.Println(gcpClient.Service.BasePath)
	fmt.Println(gcpClient.Billing.BasePath)
	fmt.Println(gcpClient.DNS.BasePath)

	// Get a List of Projects
	resp, err := gcpClient.ListProjects()
	if err != nil {
		log.Fatal(err)
	}
	for _, project := range resp.Projects {
		fmt.Printf("Project Name: %s\tProjectID: %s\r\n", project.Name, project.ProjectId)
	}

	// Get a Project
	resp1, err := gcpClient.GetProject("hidden-howl-252922")
	if err != nil {
		log.Fatal(err)
	}

	// Use the . to access the attributes of this project
	fmt.Println(resp1.Name)
	fmt.Printf("The lifecycle state of %s project is %s:", resp1.Name, resp1.LifecycleState)

	// Delete a Project
	resp2, err := gcpClient.DeleteProject("hidden-howl-252922")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(resp2.ServerResponse)

}
```
