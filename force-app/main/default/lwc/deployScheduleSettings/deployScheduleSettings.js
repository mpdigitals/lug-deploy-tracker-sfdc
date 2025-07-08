import { LightningElement } from 'lwc';
import getDeployConfig from '@salesforce/apex/DeployCoreUtils.getDeployConfig';
import updateDeployConfig from '@salesforce/apex/DeployCoreUtils.updateDeployConfig';
import deployErrorHandler from 'c/deployErrorHandler';
import { showToast } from 'c/deployToastService';

const UNIT_OPTIONS = [
  { label: 'Hours', value: 'Hours' },
  { label: 'Days', value: 'Days' }
];

const LIMITS = {
  Hours: 23,
  Days: 30
};

const TOAST_VARIANTS = {
  SUCCESS: 'success',
  WARNING: 'warning',
  ERROR: 'error'
};

const MESSAGES = {
  UNIT_REQUIRED: 'Frequency Unit is required.',
  VALUE_POSITIVE: 'Frequency Value must be a positive number.',
  tooHigh: unit => `For ${unit.toLowerCase()}, the maximum allowed value is ${LIMITS[unit]}.`,
  SAVE_OK: 'Schedule configuration saved.'
};

const LABELS = {
  HEADER_TITLE: 'Schedule Settings',
  HEADER_SUBTITLE: 'Configure periodic deployment synchronization into this org.',
  START_TIME: 'Start Time',
  FREQUENCY_UNIT: 'Frequency Unit',
  FREQUENCY_VALUE: 'Frequency Value',
  START_PLACEHOLDER: 'Later than now',
  VALUE_PLACEHOLDER: 'Numeric value',
  ENABLE_SCHEDULE: 'Enabled',
  SAVE_BUTTON_ENABLED: 'Save Configuration',
  SAVE_BUTTON_DISABLED: 'Disable Schedule'
};

export default class DeployScheduleSettings extends LightningElement {
  _startTime = '';
  _frequencyUnit = '';
  _frequencyValue = '';
  _isEnabled = false;
  _unitOptions = [];
  _isLoading = false;
  _nextRun = null;

  connectedCallback() {
    this.init();
  }

  async init() {
    await this.loadFrequencyUnits();
    await this.loadConfig();
  }

  get isSaveDisabled() {
    const valNum = Number(this._frequencyValue);
    return this._isLoading
        || !this._startTime
        || !this._frequencyUnit
        || !this._frequencyValue
        || valNum <= 0
        || (this.maxValue !== null && valNum > this.maxValue);
  }

  get headerTitle() {
    return LABELS.HEADER_TITLE;
  }

  get headerSubtitle() {
    return LABELS.HEADER_SUBTITLE;
  }

  get startTimeLabel() {
    return LABELS.START_TIME;
  }

  get frequencyUnitLabel() {
    return LABELS.FREQUENCY_UNIT;
  }

  get frequencyValueLabel() {
    return LABELS.FREQUENCY_VALUE;
  }

  get startTimePlaceholder() {
    return LABELS.START_PLACEHOLDER;
  }

  get frequencyValuePlaceholder() {
    return LABELS.VALUE_PLACEHOLDER;
  }

  get areFieldsDisabled() {
    return !this._isEnabled;
  }

  get isValueInputDisabled() {
    return !this._isEnabled || !this._frequencyUnit;
  }

  get enabledScheduleLabel() {
    return LABELS.ENABLE_SCHEDULE;
  }

  get scheduleToggleLabel() {
    return this._isEnabled
      ? LABELS.SAVE_BUTTON_ENABLED
      : LABELS.SAVE_BUTTON_DISABLED;
  }

  get saveButtonLabel() {
    return this.scheduleToggleLabel;
  }

  get minStartTime() {
      const now = new Date();
      const options = {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          hour12: false
      };

      const parts = new Intl.DateTimeFormat('en-CA', options).formatToParts(now);

      const map = {};
      parts.forEach(({ type, value }) => {
          map[type] = value;
      });

      return `${map.year}-${map.month}-${map.day}T${map.hour}:${map.minute}`;
  }

  get maxValue() {
    return LIMITS[this._frequencyUnit] ?? null;
  }

  get nextRun() {
    return this._nextRun
      ? new Date(this._nextRun).toLocaleString()
      : 'Not scheduled';
  }

  get startTime() {
    return this._startTime;
  }

  get frequencyUnit() {
    return this._frequencyUnit;
  }

  get frequencyValue() {
    return this._frequencyValue;
  }

  get unitOptions() {
    return this._unitOptions;
  }

  get isEnabled() {
    return this._isEnabled;
  }

  get isLoading() {
    return this._isLoading;
  }

  loadFrequencyUnits() {
    this._unitOptions = UNIT_OPTIONS;
  }

  async loadConfig() {
    this._isLoading = true;
    try {
      const cfg = await getDeployConfig();
      this._frequencyUnit = cfg.frequencyUnit;
      this._frequencyValue = parseInt(cfg.frequencyValue, 10)
      this._isEnabled = cfg.isEnabled;
      this._startTime = cfg.startTime;
    } catch (err) {
      deployErrorHandler(this, 'Unable to load schedule configuration', err);
    } finally {
      this._isLoading = false;
    }
  }

  handleStartTimeChange(e) {
    this._startTime = e.detail.value;
  }

  handleUnitChange(e) {
    this._frequencyUnit = e.detail.value;
  }

  handleValueChange(e) {
    this._frequencyValue = e.detail.value;
  }

  handleEnabledChange(e) {
    this._isEnabled = e.target.checked;
  }

  async handleSave() {
    if (!this._frequencyUnit) {
      this.toastValidation(MESSAGES.UNIT_REQUIRED);
      return;
    }

    const valNum = Number(this._frequencyValue);

    if (!valNum || valNum <= 0) {
      this.toastValidation(MESSAGES.VALUE_POSITIVE);
      return;
    }

    if (this.maxValue !== null && valNum > this.maxValue) {
      this.toastValidation(MESSAGES.tooHigh(this._frequencyUnit));
      return;
    }

    this._isLoading = true;

    try {
      await updateDeployConfig({
        config: 
        {
          startTime: this._startTime,
          frequencyUnit: this._frequencyUnit,
          frequencyValue: this._frequencyValue,
          isEnabled: this._isEnabled
        }
      });
      showToast(this, {
        title: 'Success',
        message: MESSAGES.SAVE_OK,
        variant: TOAST_VARIANTS.SUCCESS
      });
    } catch (err) {
      deployErrorHandler(this, 'Failed to save schedule configuration', err);
    } finally {
      this._isLoading = false;
    }
  }

  toastValidation(message) {
    showToast(this, {
      title: 'Validation',
      message,
      variant: TOAST_VARIANTS.ERROR
    });
  }
}