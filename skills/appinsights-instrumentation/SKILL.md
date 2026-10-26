---
name: appinsights-instrumentation
description: "Wire Azure Application Insights into a webapp for telemetry — requests, dependencies, exceptions, custom events. Use when: 'add app insights', 'instrument telemetry', 'track exceptions in Azure', 'wire up Application Insights', 'add observability to this app', 'send telemetry to Azure'."
---

# AppInsights instrumentation

This skill enables sending telemetry data of a webapp to Azure App Insights for better observability of the app's health.

## When to use this skill

Use this skill when the user wants to enable telemetry for their webapp.

## Prerequisites

The app in the workspace must be one of these kinds

- An ASP.NET Core app hosted in Azure
- A Node.js app hosted in Azure

## Guidelines

### Collect context information

Find out the (programming language, application framework, hosting) tuple of the application the user is trying to add telemetry support in. This determines how the application can be instrumented. Read the source code to make an educated guess. Confirm with the user on anything you don't know. You must always ask the user where the application is hosted (e.g. on a personal computer, in an Azure App Service as code, in an Azure App Service as container, in an Azure Container App, etc.).

### Prefer auto-instrument if possible

If the app is a C# ASP.NET Core app hosted in Azure App Service, use auto-instrumentation via Azure Portal (Application Insights > Enable) — no code changes needed.

### Manually instrument

Manually instrument the app by creating the AppInsights resource and update the app's code.

#### Create AppInsights resource

Use one of the following options that fits the environment.

- Add AppInsights to existing Bicep template. This is the best option if there are existing Bicep template files in the workspace.
- Use Azure CLI to create the App Insights resource.

Recommend creating the App Insights resource in the same resource group as the hosted app.

#### Modify application code

- **ASP.NET Core**: Add `Microsoft.ApplicationInsights.AspNetCore` NuGet package, call `builder.Services.AddApplicationInsightsTelemetry()`, configure connection string via `APPLICATIONINSIGHTS_CONNECTION_STRING`.
- **Node.js**: Add `applicationinsights` npm package, call `setup()` and `start()` at app entry point, configure connection string.
- **Python**: Add `azure-monitor-opentelemetry` package, call `configure_azure_monitor(connection_string=...)` at app entry point.
