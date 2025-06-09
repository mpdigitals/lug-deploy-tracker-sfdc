import { LightningElement } from 'lwc';
import syncDeployments from '@salesforce/apex/DeployService.syncDeployments';
import deployErrorHandler from 'c/deployErrorHandler';
import { showToast } from 'c/deployToastService';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const CHANNEL = '/event/DeployProgress__e';
const MAX_RANGE_DAYS = 30;

const LABELS = {
  START_DATE: 'Start Date',
  END_DATE: 'End Date',
  SYNC_NOW: 'Sync Now',
  START_DATE_PLACEHOLDER: `Max ${MAX_RANGE_DAYS} days ago`,
  END_DATE_PLACEHOLDER: 'On or before today',
  SYNC_SUCCESS_TITLE: 'Success',
  SYNC_SUCCESS_MSG: 'Deployment synchronization completed.',
  VALIDATION_TITLE: 'Validation',
  START_DATE_FUTURE_MSG: 'Start date cannot be later than today.',
  END_DATE_FUTURE_MSG: 'End date cannot be later than today.',
  START_DATE_OLDER_MSG: `Start date cannot be earlier than ${MAX_RANGE_DAYS} days ago.`,
  START_AFTER_END_MSG: 'Start date cannot be after end date.',
  END_BEFORE_START_MSG: 'End date cannot be before start date.',
  END_TOO_FAR_MSG: `End date cannot be more than ${MAX_RANGE_DAYS} days from today.`
};

export default class DeploySyncSettings extends LightningElement {
  _startDate = '';
  _endDate = '';
  _startDateError = '';
  _endDateError = '';
  _isLoading = false;
  _progress = 0;
  _subscription = null;

  connectedCallback() {
    this._isLoading = false;
    // NO suscribimos aquí
  }

  disconnectedCallback() {
    this.unsubscribeProgress();
  }

  get startDateLabel() {
    return LABELS.START_DATE;
  }

  get endDateLabel() {
    return LABELS.END_DATE;
  }

  get startDatePlaceholder() {
    return LABELS.START_DATE_PLACEHOLDER;
  }

  get endDatePlaceholder() {
    return LABELS.END_DATE_PLACEHOLDER;
  }

  get syncButtonLabel() {
    return LABELS.SYNC_NOW;
  }

  get startDate() {
    return this._startDate;
  }

  get endDate() {
    return this._endDate;
  }

  get startDateError() {
    return this._startDateError;
  }

  get endDateError() {
    return this._endDateError;
  }

  get isLoading() {
    return this._isLoading;
  }

  get progressValue() {
    return this._progress;
  }

  get minStartDate() {
    const date = new Date();
    date.setDate(date.getDate() - MAX_RANGE_DAYS);
    return date.toISOString().split('T')[0];
  }

  get maxAllowedEndDate() {
    const date = new Date();
    date.setDate(date.getDate() + MAX_RANGE_DAYS);
    return date.toISOString().split('T')[0];
  }

  get maxEndDate() {
    const today = new Date();
    return today.toISOString().split('T')[0];
  }

  get isSyncDisabled() {
    return this._isLoading || this._startDateError !== '' || this._endDateError !== '';
  }

  subscribeProgress() {
    const callback = resp => {
      const rawPct = resp?.data?.payload?.Percentage__c;
      const pct = Number(rawPct);

      if (isNaN(pct)) {
        return;
      }

      this._progress = pct;

      if (pct === 100) {
        setTimeout(() => {
          this._isLoading = false;
          this.unsubscribeProgress();

          // Mostrar Toast SOLO cuando termina
          showToast(this, {
            title: LABELS.SYNC_SUCCESS_TITLE,
            message: LABELS.SYNC_SUCCESS_MSG,
            variant: 'success'
          });
        }, 1000);
      }
    };

    if (!this._subscription) {
      subscribe(CHANNEL, -1, callback).then(s => {
        this._subscription = s;
      });

      onError(err => {
        console.error('EMP API error', err);
      });
    }
  }

  unsubscribeProgress() {
    if (this._subscription) {
      unsubscribe(this._subscription, () => {
        this._subscription = null;
      });
    }
  }

  handleStartDateChange(e) {
    const input = e.target;
    const val = input.value;
    const todayStr = this.maxEndDate;
    const minAllowedStart = this.minStartDate;

    this._startDateError = '';
    input.setCustomValidity('');

    if (val) {
      if (val > todayStr) {
        this._startDateError = LABELS.START_DATE_FUTURE_MSG;
      } else if (val < minAllowedStart) {
        this._startDateError = LABELS.START_DATE_OLDER_MSG;
      } else if (this._endDate && val > this._endDate) {
        this._startDateError = LABELS.START_AFTER_END_MSG;
      }
    }

    input.setCustomValidity(this._startDateError);
    input.reportValidity();

    if (!this._startDateError) {
      this._startDate = val;
    }
  }

  handleEndDateChange(e) {
    const input = e.target;
    const val = input.value;
    const todayStr = this.maxEndDate;
    const maxAllowedEnd = this.maxAllowedEndDate;

    this._endDateError = '';
    input.setCustomValidity('');

    if (val) {
      if (val > todayStr) {
        this._endDateError = LABELS.END_DATE_FUTURE_MSG;
      } else if (this._startDate && val < this._startDate) {
        this._endDateError = LABELS.END_BEFORE_START_MSG;
      } else if (!this._startDate && val > maxAllowedEnd) {
        this._endDateError = LABELS.END_TOO_FAR_MSG;
      }
    }

    input.setCustomValidity(this._endDateError);
    input.reportValidity();

    if (!this._endDateError) {
      this._endDate = val;
    }
  }

  async handleSync() {
    if (
      this._startDateError ||
      this._endDateError ||
      (this._startDate && this._endDate && this._startDate > this._endDate)
    ) {
      showToast(this, {
        title: LABELS.VALIDATION_TITLE,
        message: 'Please fix date errors before syncing.',
        variant: 'error'
      });
      return;
    }

    this._isLoading = true;
    this._progress = 0;

    try {
      this.unsubscribeProgress();
      await this.subscribeProgress();
      await syncDeployments({
        startDate: this._startDate || null,
        endDate: this._endDate || null
      });
    } catch (err) {
      deployErrorHandler(this, 'Failed to start synchronization', err);
      this._isLoading = false;
      this.unsubscribeProgress();
    }
  }
}