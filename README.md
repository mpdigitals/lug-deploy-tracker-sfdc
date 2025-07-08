# 🧙 Lug Deploy Tracker (Beta)

[![Codacy Grade](https://app.codacy.com/project/badge/Grade/9e802cb50f2f44f28364efb1b68a0c1b)](https://app.codacy.com/gh/mpdigitals/lug-deploy-tracker-sfdc/dashboard) [![Codacy Coverage](https://app.codacy.com/project/badge/Coverage/9e802cb50f2f44f28364efb1b68a0c1b)](https://app.codacy.com/gh/mpdigitals/lug-deploy-tracker-sfdc/dashboard)

**Beta version of a 100% native Salesforce solution to visually track, analyze and review deployment activity over time**, complementing Salesforce’s default DeployRequest retention with extended historical tracking.  
It also allows you to easily review **deployed components**, quickly identify **failed deployments**, access **deployment status** directly from deployment result records, and gain deeper visibility into your deployment process.

---

## Installation 📥

You can install **Lug Deploy Tracker** in your Salesforce org using one of the following links:

[![Install in Developer Edition](https://img.shields.io/badge/Install%20in%20Developer%20Edition-Unlocked%20Package-brightgreen?style=for-the-badge)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000AJKjIAO) [![Install in Sandbox](https://img.shields.io/badge/Install%20in%20Sandbox-Unlocked%20Package-brightgreen?style=for-the-badge)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000AJKjIAO)

---

## 🔧 Setup

You **must enable one of the following authentication methods** before using the app:

### Option 1: Session ID authentication (⚠️ uses Modify All Data permission)

- Assign the permission set **DeployAdminAccessSID** to the user.
- Select “Use Session ID” in the advanced settings.

### Option 2: Named Credential authentication (recommended, least privilege)

- Create a **Named Credential for the Tooling API** with the proper connected app.
- Assign the permission set **DeployAdminAccessNC** to the user.
- Select the Named Credential in the advanced settings.

👉 [How to create a Named Credential](https://help.salesforce.com/s/articleView?id=platform.perm_uapa_create_a_named_credential.htm&type=5)

![Advance Settings](media/images/deploy_advance_settings.png)

---

## Overview ✨

**Lug Deploy Tracker** is a Salesforce solution designed to track and analyze deployment activity by retrieving `DeployRequest` data via the Tooling API.

This app is **heavily inspired** by [Nebula Logger](https://github.com/jongpie/NebulaLogger) — though much simpler and focused on deployment tracking.  
Some structural and UI ideas are also borrowed from [chat-gpt-sfdc](https://github.com/ArnasBaronas/chat-gpt-sfdc).

---

## Features ⚙️

- 🔍 Synchronize `DeployRequest` records using Tooling API.
- 📊 Store detailed results in:
  - `DeployResult__c`
  - `DeployResultComponent__c`
  - `DeployResultTest__c`
- ⏰ Schedule automatic syncs (e.g. every hour).
- 🎛️ Configure via Lightning Web Components (LWC):
  - Manual sync
  - Schedule settings
  - Advanced options
- 🚥 Track progress with Platform Events and live progress bar.

---

## Dashboard Example 📊

![Dashboard](media/images/deploy_dashboard.png)

---

## Usage 🖥️

### Manual Synchronization

- Use the **Synchronization Settings** tab.
- Leave “Start Date” empty to fetch last 30 days.
- Leave “End Date” empty to fetch up to today.

![Synchronization Settings](media/images/deploy_sync.png)

### Scheduled Synchronization

- Configure start time + frequency (e.g. every 2 hours from 16:00).
- Next execution is displayed in the form.

![Schedule Settings](media/images/deploy_schedule.png)

---

## Visual Results 🔍

### Deploy Results

![Deploy Results](media/images/deploy_results.png)

### Deploy Result Details

![Deploy Result Details](media/images/deploy_details.png)

### Deploy Result Components

![Deploy Result Components](media/images/deploy_result_components.png)

### Deploy Result Components Related List

![Deploy Result Components Related List](media/images/deploy_component_rl.png)

### Deploy Result Tests

![Deploy Result Tests](media/images/deploy_result_tests.png)

### Deploy Result Tests Related List

![Deploy Result Tests Related List](media/images/deploy_test_rl.png)

---

## Architecture Overview 🏗️

![Architecture Diagram](media/images/deploy_schema.png)

### LWC Components

- `deploySettingsApp`
- `deployHeader`
- `deploySyncSettings`
- `deployScheduleSettings`
- `deployAdvancedSettings`
- `deployErrorHandler`
- `deployToastService`

### Apex Classes

**Service Layer**
- `DeployService`
- `DeployScheduleService`
- `DeployRequestBatch`

**Integration Layer**
- `DeployToolingClient`
- `DeployToolingClientInterface`
- `DeployToolingApiMock`

**Data Access Layer**
- `DeploySetupRepository`
- `DeployValidator`
- `DeployAccessValidator`
- `DeployCoreUtils`
- `DeployUtils`
- `DeployConstants`

**Data Mapping**
- `DeployApiWrapper`
- `DeployResultMapper`
- `DeployResultComponentMapper`
- `DeployResultTestMapper`

### Platform Events

- `DeployProgress__e`

### Custom Objects

- `DeployResult__c`
- `DeployResultComponent__c`
- `DeployResultTest__c`

### Configuration

- `DeploySetup__c` (Custom Setting)

---

## Next Steps 🚀

Planned features:

- ⚙️ Partial result handling for large batches
- 🗑️ Auto-purge of old records
- 📈 Visual code/flow coverage metrics
- 🗂️ Summary of components and test class errors

---

## Disclaimer ⚠️

This package is provided “as is”, with no guarantees. Use at your own risk.

---

## Contact & Feedback 📬

📧 develop@mpdigitals.com
