When we are writing unit tests, we want to make sure that our **unit** works as expected. Simple put, for a given input it returns an expected output. Most of the tutorials are showing very simple examples (for a good reason) where there is a function that receives two integers and returns the sum of them. In that case, the programmer writes a unit test by adding two hardcoded examples, one that passes and one that is expected to fail (to test the error logging mechanism, if it exists). In this blogpost, I'll take a look at more realistic examples, where the function under test relies on another function which you have no control. That usually happens when you are using external services, like communicating with an API or a web service or many other things. The important point is that your test can't control what that dependency returns back to your function or how it behaves. There are many things can go wrong here, the network, the external service system, and many other things. So, I will use *mocking* techniques to **simulate** both an expected and an unexpected behavior of this external dependency.

### What is an external dependency

An **external dependency** is an object in your system that your code under test interacts with and over which you have no control. Common examples are filesystems, memory, time, network connectivity, and so on.

### What is a stub

A **stub** is a controllable replacement for an existing dependency in the system. In programming, you use **stubs** to get around around the problem of external dependencies. By using a system, you can test your code without dealing with the dependency directly.

### How to test

So you can't test something? Add a layer that wraps the calls to that comething, and then mimic that layer in your tests. Let's say the function you want to test (but you cannot control) it is called `UserExists()` which registeres a user if not registered already to an external database.

> Notice that we have to always test our public/exported functions.

* Create an interface that the object under test works against.
* Replace the underlying implementation of that interface with something you have control over.

## Lets write a client for Github

I will write a client that authenticates myself with Github API and then fetches the description of my "ghostfish" repository.

```go
package main

import (
	"context"
	"fmt"
	"github.com/google/go-github/v30/github"
	"golang.org/x/oauth2"
	"log"
	"os"
)

func main() {
	// Import your GitHub token
	token := oauth2.Token{
		AccessToken: os.Getenv("GHTOKEN"),
	}
	tokenSource := oauth2.StaticTokenSource(&token)

	// Construct oAuth2 client with GitHub token
	tc := oauth2.NewClient(context.Background(), tokenSource)

	// Construct a GitHub client passing the oAuth2 client
	client := github.NewClient(tc)

	// Fetch information about the https://github.com/drpaneas/ghostfish repository
	repo, _, err := client.Repositories.Get(context.Background(), "drpaneas", "ghostfish")
	if err != nil {
		log.Fatal(err)
	}

	// Print the description of the repository
	fmt.Println(repo.GetDescription())
}
```

So far, nothing is being mocked. To run the code above you will need a pair of [GitHub's Token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) loaded into an environment variable:

```zsh
$ export GHTOKEN="your token"
```

Running it:

```zsh
$ go build
$ ./gh-client
A TCP Scanner written in Go
```

## Separation of concerns

Having everything into a single `main()` function is quite hard to write good unit-tests. A call to `main()` in the test will do multiple network requests to GitHub's API, which is not what we intend to do. Let's break the code apart:

```go
package main

import (
	"context"
	"fmt"
	"github.com/google/go-github/v30/github"
	"golang.org/x/oauth2"
	"log"
	"os"
)

func main() {
	client := NewGithubClient()
	repo, err := GetUserRepo(client, "drpaneas")
	if err != nil {
		fmt.Println("Error")
		log.Fatal(err)
	}
	fmt.Println(repo.GetDescription())
}

func NewGithubClient() *github.Client {
	token := oauth2.Token{
		AccessToken: os.Getenv("GHTOKEN"),
	}
	tokenSource := oauth2.StaticTokenSource(&token)
	tc := oauth2.NewClient(context.Background(), tokenSource)
	client := github.NewClient(tc)
	return client
}

func GetUserRepo(client *github.Client, user string) (*github.Repository, error) {
	repo, _, err := client.Repositories.Get(context.Background(), user, "ghostfish")
	if err != nil {
		return nil, err
	}
	return repo, err
}
```

Better! Two distinct functions were defined:

* `NewGithubClient()` authenticates and returns a client to be used in subsequent operations, like getting the list of repositories.
* `GetUserRepo()` gets the user's repository

**Notice**: The `GetUserRepo()` accepts a `*github.Client` to do the GitHub request, this is the beginning of the dependency injection pattern. The client is being _injected_ into the function that will use it. Could we inject a _mock_ one? Before answering this question, take a look at this simple test:

```go
// main_test.go
package main_test

import (
	. "github.com/drpaneas/gh-client"
	"os"
	"testing"
)

func TestGetUserRepos(t *testing.T) {
	os.Setenv("GHTOKEN", "fake token")
	client := NewGithubClient()
	repo, err := GetUserRepo(client, "whatever")
	if err != nil {
		t.Errorf("Expected nil, got %s", err)
	}

	if repo.GetDescription() != "A TCP Scanner written in Go" {
		t.Errorf("extected 'A TCP Scanner written in Go', got %s", repo.GetDescription())
	}

}
```

Run it:

```zsh
$ go test
--- FAIL: TestGetUserRepos (1.77s)
    main_test.go:14: Expected nil, got GET https://api.github.com/repos/whatever/ghostfish: 401 Bad credentials []
    main_test.go:18: extected 'A TCP Scanner written in Go', got ''
FAIL
exit status 1
FAIL    github.com/drpaneas/gh-client   3.896s
```

The program returns an error, trying to authenticate with our fake `GHTOKEN` . We don't want that.

## Interfaces to the rescue

Imagine we could create a mock for `*github.Client` with the same `Repositories.Get()` method and signature and inject it into the `GetUserRepo()` method during the test. Go is statically typed language and with the current implementation only `*github.Client` can be passed into `GetUserRepo()`. Thus, it needs to be refactored to accept **any type** with a `Repositories.Get()`, like a mock client.

Fortunately, Go has the concept of `interface` which is a type with a set of metho signatures. If _any type_ implements those methods, it _satisfies_ the interface and be recognized by the interface's type. Now this situation is a a little bit _tricky_ because the `Get` function is on a `Repositories` field in the `*github.Client`, not directly on the client. As a result, instead of creating a mock for the `github.Client` with the same `Repositories.Get()` function (as I said in the beginning), I will create a mock for the `github.Client.Repositories` field with the same `Get()` method. Doing this, I would have to change the code a bit first. Simply put, my target goal is to simulate this:

```diff
- repo, _, err := client.Repositories.Get(context.Background(), user, "ghostfish")
+ repo, _, err := <interface>.Get(context.Background(), user, "ghostfish")
```

Here's the code changes needed to be done:

```go
// Change the call by passing the `.Repositories` of the `client`, instead of the whole `client` itself.
repo, err := GetUserRepo(client.Repositories, "drpaneas")

// Change the GetUserRepo() to accept the correct type
// call the Get() function from this type
func GetUserRepo(repos *github.RepositoriesService, user string) (*github.Repository, error) {
	repo, _, err := repos.Get(context.Background(), user, "ghostfish")
	if err != nil {
		return nil, err
	}
	return repo, err
}
```

Great! Now let's fix the test accordingly:

```diff
- 	repo, err := GetUserRepo(client, "whatever")
+   repo, err := GetUserRepo(client.Repositories, "whatever")
```

The code build and runs perfectly fine -- the same as before -- but the test is still failing with the same error. That is fine, because now we are using calling the `Get()` function in a `A.Get()` style, instead of `A.B.Get()`. Meaning, we need to just create an `A` interface that has a `Get()` function. This is our interface below:

```go
type Repositories interface {
	Get (ctx context.Context, owner, repo string) (*github.Repository, *github.Response, error)
}
```

Now the only change needed is to *replace* the usage of `repos.Get()` to be from our `Repositories` interface instead of the 3rd party library `*github.RepositoriesService`. To do that, we simply do this change in the signature of the `GetUserRepo()`:

```diff
- func GetUserRepo(repos *github.RepositoriesService, user string) (*github.Repository, error) {
+ func GetUserRepo(repos Repositories, user string) (*github.Repository, error) {
```

So the final code including all the changes, looks like this:

```go
package main

import (
	"context"
	"fmt"
	"github.com/google/go-github/v30/github"
	"golang.org/x/oauth2"
	"log"
	"os"
)

// 1
type Repositories interface {
	Get (ctx context.Context, owner, repo string) (*github.Repository, *github.Response, error)
}

func main() {
	client := NewGithubClient()
	repo, err := GetUserRepo(client.Repositories, "drpaneas")   // 2
	if err != nil {
		fmt.Println("Error")
		log.Fatal(err)
	}
	fmt.Println(repo.GetDescription())
}

func NewGithubClient() *github.Client {
	token := oauth2.Token{
		AccessToken: os.Getenv("GHTOKEN"),
	}
	tokenSource := oauth2.StaticTokenSource(&token)
	tc := oauth2.NewClient(context.Background(), tokenSource)
	client := github.NewClient(tc)
	return client
}

// 3
func GetUserRepo(repos Repositories, user string) (*github.Repository, error) {
	repo, _, err := repos.Get(context.Background(), user, "ghostfish")
	if err != nil {
		return nil, err
	}
	return repo, err
}
```

* 1: Creates the interface with the name of the _field_ called `Repositories` with the same `Get()` signature from `*github.Client`.
* 2: Change the call by passing the `.Repositories` of the `client`, instead of the whole `client` itself.
* 3: Change the signature to use the Interface instead of the 3rd party library `github.com/google/go-github/v30/github`

The code builds and run as expected and the tests are still failing with the same error as before. So, you might wonder **what is the difference now?**. Well, that is a very good question and if you can answer it, it means you have understood the topic of this article. Before, the code was using **directly** the `Get()` function from `github.com/google/go-github/v30/github`. Now, the code is _still_ uses this function (we cannot avoid this of course), but **indirectly**. The `Get()` function is now talking to our interface, and our interface is providing its output by calling the _actual_ function behind-the-scenes.

```go
// Before
GetUserRepo() --> 3rd Party depedency

// After
GetUserRepo() --> Interface --> 3rd Party dependency
```

Did you understand the difference a bit better now? Yet, there is a new question lying around this time: **why we did this? what is the benefit?**. This is the next best question you should ask, and is the last one (I promise). Remember the original problem? Writing a test that is _not using the 3rd party library_. Our test is still using it though, and it fails because we pass it fake ID tokens. But now, we can actually fix this once and for all.

Now, we can create a mock struct simulating behavior of the original `Get()` function. To do that, we will use a little help from the [GoMock](https://github.com/golang/mock) framework. You need to install it first:

```go
// You need a new Go version that works with Go modules
GO111MODULE=on go get github.com/golang/mock/mockgen@latest
```

We use `mockgen` to generate our mocking implementation of our interface:

```zsh
$ mockgen \
    -source=main.go \
    -destination=mocks/mock_repositories.go \
    -package=$GOPACKAGE
```

This will generate a new file `mock_repositories.go` under a new folder `mocks` that looks like this:

```go
// Code generated by MockGen. DO NOT EDIT.
// Source: main.go

// Package mock_main is a generated GoMock package.
package mock_main

import (
	context "context"
	gomock "github.com/golang/mock/gomock"
	github "github.com/google/go-github/v30/github"
	reflect "reflect"
)

// MockRepositories is a mock of Repositories interface
type MockRepositories struct {
	ctrl     *gomock.Controller
	recorder *MockRepositoriesMockRecorder
}

// MockRepositoriesMockRecorder is the mock recorder for MockRepositories
type MockRepositoriesMockRecorder struct {
	mock *MockRepositories
}

// NewMockRepositories creates a new mock instance
func NewMockRepositories(ctrl *gomock.Controller) *MockRepositories {
	mock := &MockRepositories{ctrl: ctrl}
	mock.recorder = &MockRepositoriesMockRecorder{mock}
	return mock
}

// EXPECT returns an object that allows the caller to indicate expected use
func (m *MockRepositories) EXPECT() *MockRepositoriesMockRecorder {
	return m.recorder
}

// Get mocks base method
func (m *MockRepositories) Get(ctx context.Context, owner, repo string) (*github.Repository, *github.Response, error) {
	m.ctrl.T.Helper()
	ret := m.ctrl.Call(m, "Get", ctx, owner, repo)
	ret0, _ := ret[0].(*github.Repository)
	ret1, _ := ret[1].(*github.Response)
	ret2, _ := ret[2].(error)
	return ret0, ret1, ret2
}

// Get indicates an expected call of Get
func (mr *MockRepositoriesMockRecorder) Get(ctx, owner, repo interface{}) *gomock.Call {
	mr.mock.ctrl.T.Helper()
	return mr.mock.ctrl.RecordCallWithMethodType(mr.mock, "Get", reflect.TypeOf((*MockRepositories)(nil).Get), ctx, owner, repo)
}
```

This means, we can _import_ this file in our tests -- instead of the 3rd party library:

```diff
- . "github.com/drpaneas/gh-client"