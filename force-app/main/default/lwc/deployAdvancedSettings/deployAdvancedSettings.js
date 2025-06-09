import { LightningElement } from 'lwc';
import getDeployConfig from '@salesforce/apex/DeployCoreUtils.getDeployConfig';
import updateAdvancedSettings from '@salesforce/apex/DeployCoreUtils.updateAdvancedSettings';
import getNamedCredentials from '@salesforce/apex/DeployCoreUtils.getNamedCredentials';
import deployErrorHandler from 'c/deployErrorHandler';
import { showToast } from 'c/deployToastService';

const TOAST = {
  ERROR: 'error',
  SUCCESS: 'success'
};

const LABELS = {
  HEADER_TITLE: 'Advanced Settings',
  HEADER_SUBTITLE: 'Manage synchronization settings for deployment monitoring.',
  VISIBILITY_TITLE: 'Visibility Settings',
  EXECUTION_TITLE: 'Execution Settings',
  RETRIEVE_COMPONENTS: 'Retrieve Components',
  RETRIEVE_TESTS: 'Retrieve Tests',
  RETRIEVE_INTERMEDIATE: 'Retrieve Intermediate States',
  BATCH_SIZE: 'Batch Size',
  NAMED_CREDENTIAL: 'Named Credential',
  NAMED_CREDENTIAL_PLACEHOLDER: 'Select a Named Credential',
  SAVE: 'Save Configuration'
};

const MSG = {
  VALIDATION_NAMED_CRED: 'Named Credential is required.',
  VALIDATION_BATCH_SIZE: 'Batch Size must be between 1 and 100.',
  SAVE_SUCCESS: 'Advanced settings saved successfully.'
};

export default class DeployAdvancedSettings extends LightningElement {
  _retrieveComponents = true;
  _retrieveTests = true;
  _retrieveIntermediateStates = false;
  _batchSize = 100;
  _namedCredential = '';
  _namedCredentialOpts = [];
  _isLoading = false;

  connectedCallback() {
    this.init();
  }

  init() {
    this.loadData();
  }

async loadData() {
    this._isLoading = true;
    try {
        const [cfg, creds] = await Promise.all([
            getDeployConfig(),
            getNamedCredentials()
        ]);

        if (!cfg.namedCredential) {
            this._retrieveComponents = true;
            this._retrieveTests = true;
        } else {
            this._retrieveComponents = cfg.retrieveComponents ?? true;
            this._retrieveTests = cfg.retrieveTests ?? true;
        }

        this._retrieveIntermediateStates = cfg.retrieveIntermediateStates ?? false;
        this._batchSize = cfg.batchSize;
        this._namedCredential = cfg.namedCredential;

        this._namedCredentialOpts = creds.map(n => {
            return { label: n, value: n };
        });
    } catch (err) {
        deployErrorHandler(this, 'Unable to load advanced settings', err);
    } finally {
        this._isLoading = false;
    }
}

  get headerTitle() {
    return LABELS.HEADER_TITLE;
  }

  get headerSubtitle() {
    return LABELS.HEADER_SUBTITLE;
  }

  get visibilitySectionTitle() {
    return LABELS.VISIBILITY_TITLE;
  }

  get executionSectionTitle() {
    return LABELS.EXECUTION_TITLE;
  }

  get retrieveComponentsLabel() {
    return LABELS.RETRIEVE_COMPONENTS;
  }

  get retrieveTestsLabel() {
    return LABELS.RETRIEVE_TESTS;
  }

  get retrieveIntermediateLabel() {
    return LABELS.RETRIEVE_INTERMEDIATE;
  }

  get batchSizeLabel() {
    return LABELS.BATCH_SIZE;
  }

  get namedCredentialLabel() {
    return LABELS.NAMED_CREDENTIAL;
  }

  get namedCredentialPlaceholder() {
    return LABELS.NAMED_CREDENTIAL_PLACEHOLDER;
  }

  get saveButtonLabel() {
    return LABELS.SAVE;
  }

  get retrieveComponents() {
    return this._retrieveComponents;
  }

  get retrieveTests() {
    return this._retrieveTests;
  }

  get retrieveIntermediateStates() {
    return this._retrieveIntermediateStates;
  }

  get batchSize() {
    return this._batchSize;
  }

  get namedCredential() {
    return this._namedCredential;
  }

  get namedCredentialOptions() {
    return this._namedCredentialOpts;
  }

  get isLoading() {
    return this._isLoading;
  }

  get isSaveDisabled() {
    return (
      this._isLoading ||
      !this._namedCredential || 
      !Number.isInteger(this._batchSize) || 
      this._batchSize < 1 || 
      this._batchSize > 100
    );
  }

  handleRetrieveComponentsChange(e) {
    this._retrieveComponents = e.target.checked;
  }

  handleRetrieveTestsChange(e) {
    this._retrieveTests = e.target.checked;
  }

  handleRetrieveIntermediateChange(e) {
    this._retrieveIntermediateStates = e.target.checked;
  }

  handleBatchSizeChange(e) {
    this._batchSize = Number(e.target.value);
  }

  handleNamedCredentialChange(e) {
    this._namedCredential = e.detail.value;
  }

  async handleSave() {
    if (!this._namedCredential) {
      showToast(this, {
        title: 'Validation',
        message: MSG.VALIDATION_NAMED_CRED,
        variant: TOAST.ERROR
      });
      return;
    }

    if (!Number.isInteger(this._batchSize) || this._batchSize < 1 || this._batchSize > 100) {
      showToast(this, {
        title: 'Validation',
        message: MSG.VALIDATION_BATCH_SIZE,
        variant: TOAST.ERROR
      });
      return;
    }

    this._isLoading = true;
    try {
      await updateAdvancedSettings({
        config: {
          retrieveComponents: this._retrieveComponents,
          retrieveTests: this._retrieveTests,
          retrieveIntermediateStates: this._retrieveIntermediateStates,
          batchSize: this._batchSize,
          namedCredential: this._namedCredential
        }
      });

      showToast(this, {
        title: 'Success',
        message: MSG.SAVE_SUCCESS,
        variant: TOAST.SUCCESS
      });
    } catch (err) {
      deployErrorHandler(this, 'Failed to save advanced settings', err);
    } finally {
      this._isLoading = false;
    }
  }
}