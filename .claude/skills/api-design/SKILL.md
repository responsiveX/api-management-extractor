---
name: api-design
description: |
  Use this skill when working with openapi specifications or aspnet core endpoints/controller actions. Includes some Amusement Connect specific conventions around api design so this skill should be consulted even when doing routine api work.
  Triggers on phrases like "update the endpoint", "add an endpoint", "update the api spec", "add to the openapi doc", "update the swagger file", and similar. Also trigger automatically when opening a .cs file under a Controllers/ or Endpoints/ folder, or a .yaml/.yml file under openapi/models/ or openapi/reference/.
---

# API Design and Specifications

Design or edit API endpoints, making sure the openapi specification and the implementation are in sync and follow standard Amusement Connect conventions.

## Conventions

- Resource names in routes should be singular (e.g., `/user` not `/users`) unless the resource is inherently plural (e.g., `/news`).
- Routes should be lowercase and use hyphens to separate words (e.g., `/user-profile` not `/UserProfile` or `/user_profile`).
- Use nouns for resource names and avoid verbs in route paths (e.g., `/user` not `/getUser`).
- Http methods should follow RESTful conventions: `GET` for retrieval, `POST` for creates or actions on a resource, `DELETE` for removing a resource, and `PUT` is where we break conventions a little. We use `PUT` only for complete updates of a resource, and partial updates are done via a `POST` method, typically on a sub-resource (e.g. `POST /user/{id}/profile` for updating the user's profile information, `POST /user/{id}/avatar` for updating the user's avatar).
- Query parameters that represent a collection of values should use the explode format (e.g., `?status=active&status=pending`) and in code would bind to something like `[FromQuery] ExampleStatusEnum[] status`.
- Any changes to an API request or response that would result in a breaking change for existing clients should be done in a new version of the api (e.g. `/user?apiVersion=2.0`)
- All endpoints should use versioning (some exceptions exist for internal health check and build number check endpoints). Versioning is done via a query parameter `apiVersion` and uses the `{Major}.{Minor}` format.

## OpenAPI Specification

When working with api endpoints in a project the open api specification file should be used as the source of truth for the API contract. Any changes made to the Controllers or Endpoints should be reflected in the openapi specification file.

The openapi specifications are typically organized like so from the project root:

```
src/
  openapi/
    reference/
      {apiname}-openapi.yaml
    models/
      {model-name}.yaml
    tools/
      redocly-cli/
        {apiname}-bundle.ps1
        {apiname}-docs.ps1
    bundled/
      {apiname}-openapi.yaml
```

There may be some small variations in the names but the folders will be consistent.
The `reference` folder contains the main openapi specification files that define the API contract. The `models` folder contains yaml files that define the data models used in the API. The `tools/redocly-cli` folder contains scripts for bundling and generating documentation from the openapi specifications using the openapi-generator-cli from a docker container. The `bundled` folder contains the output of the bundling process, which combines the reference and models into a single file for use in documentation generation. The bundled files should be ignored by git and are only used as intermediate files.

We use a custom property on operations in the openapi spec called `x-scopes` to define the required scopes for an endpoint. The value is a list of strings. e.g. `x-scopes: ["user:read", "user:write"]`.

When defining parameters for paths and operations in the openapi spec, define route parameters in the path item object so that they apply to all operations under that path unless there is a specific reason why they must be defined separately. Defining query parameters at the path object is discouraged, typically they should be defined at the operation level. There is one very important exception to this though, which is the `apiVersion` query parameter.

The `apiVersion` query parameter should be defined on every path item object in the openapi spec. It is an enum of the supported API versions for that endpoint and should be defined at the path level.

Openapi specifications don't support query string versioning for operations very well, so the standard procedure is that we have a openapi spec file for each version of the API.

### Versioning

When making breaking changes to an API contract, a new version of the API needs to be created. Each openapi specification file should only define operations for a single api version. The spec files for version 1.0 of the API's are typically named `{apiname}-openapi.yaml` and then when a new version of the API is created, copy the previous spec and name it like `{apiname}-{MajorVersion}_{MinorVersion}-openapi.yaml` (e.g. `user-2_0-openapi.yaml`). The new version of the API should be added to the `apiVersion` enum in the path item objects in the openapi spec, and any new endpoints or changes to existing endpoints should be made in the new version's openapi spec file. The old version of the API should be left in place until it is deprecated and removed in a future release, but any changes to the old version's endpoints should be avoided if possible.

## ASP.NET Core

When working with ASP.NET Core minimal apis or controllers, the code should be organized in a way that reflects the structure of the API. Controllers should be used to group related endpoints together, and each endpoint should be defined as a method within the controller. The common base route for the action methods in a controller should be set by the `[Route("path/to/controller")]` attribute on the controller, then each endpoint should be defined using the HTTP method attribute (e.g., `[HttpGet("{id:guid}")]`, `[HttpPost]`, etc.). If the project is instead using minimal APIs, each endpoint should be it's own file and there should be a file that maps all the endpoints to routes/methods, either all in one file, or broken out into endpoint groups. The parameters for each endpoint should be defined using attributes as well (e.g., `[FromRoute]` `[FromQuery]`, `[FromBody]`, etc.).

Any changes made to the endpoints or controllers should be reflected in the openapi specification file to ensure that the API contract remains consistent.

The request and response models should be created in the `requests` or `responses` folders within the web api project. The models don't always have to follow the openapi specifications for things like `oneOf`/`anyOf` as long as a request matching the openapi spec can be properly deserialized into the request model or serialized into the response model.

Typically request models will never need to have their values changed after being deserialized, so their properties can be defined with init accessors, or for small objects record types can be used. Response models should default to being immutable, but there may be some cases (especially with larger responses or responses with complex filtering/projection logic) where it is more elegant to have a mutable response model.

When processing requests for an endpoint there should always be a clear separation between the request/response models and any domain models or business logic.

Never reuse a class from the other layers of the application in the request or response models (or as one). There is the risk that a property could be added to the domain model that is not intended to be exposed in the API and it would make changes to the domain models more difficult since there would be a risk of breaking the API contract. The request and response models should be simple DTOs that are only used for the purpose of deserializing incoming requests and serializing outgoing responses. The domain models should be separate classes that represent the core business entities and logic of the application. The controller or endpoint is responsible for mapping between the request/response models and the domain models, and for orchestrating the business logic to process the request and produce the response. This separation of concerns helps to keep the codebase organized, maintainable, and flexible to changes in the future.

Endpoints that are readonly should support cancellation all the way through to the data access layers. Endpoints that modify data should not support cancellation unless there is a specific reason to do so and any modifications that may have been started are able to be rolled back reliably. Typically it's easiest to have the request be idempotent, support idempotency keys, or use ETags for important data modifying endpoints. There is a custom attribute to enforce scope requirements on an endpoint `[RequireScope("scope-name")]` which can be used on controllers or actions, and supports multiple scopes too `[RequireScope("user:read", "user:write")]`. Make sure this stays in sync with the `x-scopes` property in the openapi specification for the endpoint.

Be careful whenever logging user provided data from the request to not log any potentially sensitive information, and to make sure that strings are always properly sanitized to prevent log injection attacks.

### Validation

Use fluent validation for validating incoming requests. Create a validator class the request model being validated. In the action method with the request being validated use the validator like:

```csharp
var validator = new CreateUserRequestValidator();
await validator.ValidateAndThrowAsync(request, cancellationToken);
```

When a request model has properties that themselves are complex objects create another validator for that model and use the `SetValidator` method in the parent validator to validate the nested model. Maintain two constructors for the validator class, one that supports providing IValidator<> instances for each child validator being used, and a parameterless constructor that news up each one e.g.

```csharp
// CreateUserRequest.cs
public class CreateUserRequest
{
    public CreateUserProfileRequestModel Profile { get; init; } = new();
}

// CreateUserProfileRequestModel.cs
public class CreateUserProfileRequestModel
{
    public string? FirstName { get; init; }
    public string? LastName { get; init; }
}

// CreateUserProfileRequestValidator.cs
public class CreateUserProfileRequestValidator : AbstractValidator<CreateUserProfileRequestModel>
{
    public CreateUserProfileRequestValidator()
    {
        RuleFor(x => x.FirstName)
          .MaximumLength(50)
          .MinimumLength(2)
          .When(x => !string.IsNullOrEmpty(x.FirstName));

        RuleFor(x => x.LastName)
          .MaximumLength(50)
          .MinimumLength(2)
          .When(x => !string.IsNullOrEmpty(x.LastName));
    }
}

// CreateUserRequestValidator.cs
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator() : this(new CreateUserProfileRequestValidator())
    {

    }

    public CreateUserRequestValidator(
        IValidator<CreateUserProfileRequestModel> profileValidator
    )
    {
        RuleFor(x => x.Profile).SetValidator(profileValidator);
    }
}
```

This allows for better testability of the validators, keeps validation logic reusable and as close to the request models as possible, provides opportunities for composing and extending validators, and allows for us to possibly use dependency injection for validators in the future if we choose to go that route.

Validators should not be used for validating things that are not part of the request model, such as validating that a user has permission to perform an action, or validating that a resource exists in the database. Those types of validations should be done separately in the controller or endpoint after the request model has been validated, and they should utilize the `ModelState` object. The goal with the fluent validation validators is to have obviously bad requests that don't meet the defined specification fail fast, provide clear feedback to the requesting client why the request wasn't valid, and not have those utilize our limited database resources.

We utilize problem details error responses and support the validation problem details format for validation errors. There is a middleware that intercepts any `ValidationException` thrown by fluent validation and converts it into a 400 response with the validation problem details format. For other types of exceptions that are not handled and result in a 500 response, there is another middleware that converts those into a problem details response as well.

If a request targting a resource that does not exist is made, the API should return a 404 response, with the problem details response body with the detail property using a message like "{ResourceType} Not Found" ("User Not Found", "Game Not Found", etc.) This is especially helpful if the request has multiple route parameters that could be referring to different resource types (e.g. `POST /card/{cardNumber}/location/{locationId}/balance` could return "Card Not Found" or "Location Not Found" depending on which resource was not found).

### Asp.Versioning

We use the library `Asp.Versioning` for handling API versioning in our ASP.NET Core projects. This library provides a convenient way to manage multiple versions of an API and to route requests to the correct version based on the `apiVersion` query parameter. When defining controllers or endpoints, we can use the `[ApiVersion("1.0")]` attribute to specify which version(s) of the API they belong to. The library will then take care of routing requests with the appropriate `apiVersion` to the correct controller or endpoint.

A controller can support multiple versions of an API by using multiple `[ApiVersion]` attributes. If multiple versions of an action method exist within the same controler the `[MapToApiVersion]` attribute can be used on the action method to specify which version(s) of the API it belongs to. If an action method does not have a `[MapToApiVersion]` attribute, it will be assumed to belong to all versions specified at the controller level.

## Api Management

To get get changes to an API into Azure API Management requires the developer to import the bundled openapi specification file(s) to the development instance of API Management, the run the extractor tool at `deploy/api-management/extractorHelper.ps1` to extract the arm template for the API in API Management, and the XML policy files for each operation so they can be checked into source control and deployed to the other environments. Anytime a new tag is introduced in the openapi spec an additional step must be taken to create it in API Management; The extractor tool in the `azure-shared-infrastructure` repository needs to be ran to extract the arm template for the tag resources in apim, then checked in to that repo. If there has been any changes to the openapi spec always remind the developer to update API Management. Always make sure the bundled openapi specification file is up to date before importing to API Management.