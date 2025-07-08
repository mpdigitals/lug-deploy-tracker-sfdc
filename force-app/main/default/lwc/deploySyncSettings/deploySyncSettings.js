import { LightningElement } from 'lwc'
import syncDeployments from '@salesforce/apex/DeployService.syncDeployments'
import getBatchStatus from '@salesforce/apex/DeployRequestBatch.getBatchStatus'
import deployErrorHandler from 'c/deployErrorHandler'
import { showToast } from 'c/deployToastService'
import { subscribe, unsubscribe, onError } from 'lightning/empApi'

const CHANNEL = '/event/DeployProgress__e'
const META_CONNECT_CHANNEL= '/meta/connect'
const MAX_RANGE_DAYS = 30
const POLLING_INTERVAL_MS = 30000
const MAX_POLLING_ATTEMPTS = 20
const POLLING_TIMEOUT_MSG = 'The process is taking longer than expected. It will continue in the background.'

const STATUS = {
  ABORTED: 'Aborted',
  FAILED: 'Failed',
  COMPLETED: 'Completed'
}

const TOAST_VARIANTS = {
  SUCCESS: 'success',
  WARNING: 'warning',
  ERROR: 'error'
}

const LABELS = {
  START_DATE_PLACEHOLDER: `Max ${MAX_RANGE_DAYS} days ago`,
  END_DATE_PLACEHOLDER: 'On or before today',
  SYNC_NOW: 'Sync Now',
  SYNC_SUCCESS_TITLE: 'Success',
  SYNC_SUCCESS_MSG: 'Deployment synchronization completed.',
  SYNC_ABORTED_MSG: 'Synchronization aborted.',
  SYNC_FAILED_MSG: 'Synchronization failed.',
  SYNC_ERROR_CHECKING_MSG: 'Error checking batch status.',
  VALIDATION_TITLE: 'Validation',
  START_DATE_FUTURE_MSG: 'Start date cannot be later than today.',
  END_DATE_FUTURE_MSG: 'End date cannot be later than today.',
  START_DATE_OLDER_MSG: `Start date cannot be earlier than ${MAX_RANGE_DAYS} days ago.`,
  START_AFTER_END_MSG: 'Start date cannot be after end date.',
  END_BEFORE_START_MSG: 'End date cannot be before start date.',
  END_TOO_FAR_MSG: `End date cannot be more than ${MAX_RANGE_DAYS} days from today.`,
  ERROR_TITLE: 'Error',
  WARNING_TITLE: 'Warning',
  VALIDATION_FAILED_MSG: 'Please fix date errors before syncing.',
  SYNC_START_FAILED_MSG: 'Failed to start synchronization'
}

export default class DeploySyncSettings extends LightningElement {
_startDate = ''
_endDate = ''
_startDateError = ''
_endDateError = ''
_isLoading = false
_progress = 0
_lastBatchId = null
_batchHandled = false
_subscription = null
_pollingInterval = null
_pollingAttempts = 0
_empApiErrored = false

  disconnectedCallback() {
    this._unsubscribeProgress()
    this._stopPolling()
  }

  get startDatePlaceholder() {
    return LABELS.START_DATE_PLACEHOLDER
  }

  get endDatePlaceholder() {
    return LABELS.END_DATE_PLACEHOLDER
  }

  get syncButtonLabel() {
    return LABELS.SYNC_NOW
  }

  get isLoading() {
    return this._isLoading
  }

  get progressValue() {
    return this._progress
  }

  get minStartDate() {
    const d = new Date()
    d.setDate(d.getDate() - MAX_RANGE_DAYS)
    return d.toISOString().split('T')[0]
  }

  get maxEndDate() {
    return new Date().toISOString().split('T')[0]
  }

  get isSyncDisabled() {
    return (
      this._isLoading ||
      this._startDateError !== '' ||
      this._endDateError !== ''
    )
  }

  _subscribeProgress() {
    if (this._subscription || this._empApiErrored) {
      return
    }

    const cb = async evt => {
      const pct = Number(evt?.data?.payload?.Percentage__c)
      if (isNaN(pct)) {
        return
      }

      this._progress = pct

      if (pct === 100 && this._lastBatchId && !this._batchHandled) {
        try {
          const res = await getBatchStatus({ batchId: this._lastBatchId })
          if (res.status === STATUS.COMPLETED) {
            this._handleBatchResult(res)
          }
        } catch (e) {
          this._stopPolling()
          deployErrorHandler(this, LABELS.SYNC_ERROR_CHECKING_MSG, e)
        }
      }
    }

    subscribe(CHANNEL, -1, cb)
      .then(resp => {
        this._subscription = resp
      })
      .catch(e => {
        this._empApiErrored = true
        this._stopPolling()
        deployErrorHandler(this, LABELS.SYNC_ERROR_CHECKING_MSG, e)
      })

    onError(err => {
      if (err?.channel === META_CONNECT_CHANNEL) {
        return
      }
    })
  }

  _unsubscribeProgress() {
    if (this._subscription) {
      unsubscribe(this._subscription, () => {
        this._subscription = null
      })
    }
  }

  _startPolling() {
    this._stopPolling()
    this._pollingAttempts = 0
    this._pollingInterval = setInterval(() => this._checkBatchStatus(), POLLING_INTERVAL_MS)
  }

  _stopPolling() {
    if (this._pollingInterval) {
      clearInterval(this._pollingInterval)
      this._pollingInterval = null
    }
  }

  async _checkBatchStatus() {
    if (!this._lastBatchId || this._batchHandled) {
      return
    }

    this._pollingAttempts++

    if (this._pollingAttempts >= MAX_POLLING_ATTEMPTS) {
      this._batchHandled = true
      this._unsubscribeProgress()
      this._stopPolling()
      this._isLoading = false
      this._progress = 100
      this._showToast(
        LABELS.WARNING_TITLE,
        POLLING_TIMEOUT_MSG,
        TOAST_VARIANTS.WARNING
      )
      return
    }

    try {
      const res = await getBatchStatus({ batchId: this._lastBatchId })
      if (Object.values(STATUS).includes(res.status)) {
        this._handleBatchResult(res)
      }
    } catch (err) {
      if (this._empApiErrored && err?.channel === META_CONNECT_CHANNEL) {
        return
      }
      this._stopPolling()
      deployErrorHandler(this, LABELS.ERROR_TITLE, err)
    }
  }

  _handleBatchResult(res) {
    if (this._batchHandled) {
      return
    }

    this._batchHandled = true
    this._unsubscribeProgress()
    this._stopPolling()
    this._isLoading = false

    const status = res.status
    const errors = Number(res.numberOfErrors || 0)
    const msg = (res.extendedStatus || '').trim()

    if (status === STATUS.ABORTED) {
      deployErrorHandler(this, LABELS.ERROR_TITLE, LABELS.SYNC_ABORTED_MSG)
    } else if (status === STATUS.FAILED) {
      deployErrorHandler(this, LABELS.ERROR_TITLE, msg || LABELS.SYNC_FAILED_MSG)
    } else if (status === STATUS.COMPLETED) {
      if (errors > 0) {
        this._showToast(LABELS.WARNING_TITLE, msg || LABELS.SYNC_FAILED_MSG, TOAST_VARIANTS.WARNING)
      } else {
        this._showToast(LABELS.SYNC_SUCCESS_TITLE, LABELS.SYNC_SUCCESS_MSG, TOAST_VARIANTS.SUCCESS)
      }
    }
  }

  _showToast(title, message, variant) {
    showToast(this, { title, message, variant })
  }

  handleStartDateChange(e) {
    const v = e.target.value
    const today = this.maxEndDate
    const min = this.minStartDate
    this._startDateError = ''

    if (v > today) {
      this._startDateError = LABELS.START_DATE_FUTURE_MSG
    } else if (v < min) {
      this._startDateError = LABELS.START_DATE_OLDER_MSG
    } else if (this._endDate && v > this._endDate) {
      this._startDateError = LABELS.START_AFTER_END_MSG
    }

    e.target.setCustomValidity(this._startDateError)
    e.target.reportValidity()

    if (this._startDateError === '') {
      this._startDate = v
    }
  }

  handleEndDateChange(e) {
    const v = e.target.value
    const today = this.maxEndDate
    const max = this.maxEndDate
    this._endDateError = ''

    if (v > today) {
      this._endDateError = LABELS.END_DATE_FUTURE_MSG
    } else if (this._startDate && v < this._startDate) {
      this._endDateError = LABELS.END_BEFORE_START_MSG
    } else if (!this._startDate && v > max) {
      this._endDateError = LABELS.END_TOO_FAR_MSG
    }

    e.target.setCustomValidity(this._endDateError)
    e.target.reportValidity()

    if (this._endDateError === '') {
      this._endDate = v
    }
  }

  async handleSync() {
    if (
      this._startDateError !== '' ||
      this._endDateError !== '' ||
      (this._startDate && this._endDate && this._startDate > this._endDate)
    ) {
      this._showToast(LABELS.VALIDATION_TITLE, LABELS.VALIDATION_FAILED_MSG, TOAST_VARIANTS.ERROR)
      return
    }

    this._isLoading = true
    this._progress = 0
    this._lastBatchId = null
    this._batchHandled = false
    this._empApiErrored = false
    this._pollingAttempts = 0

    try {
      this._unsubscribeProgress()
      this._stopPolling()
      this._subscribeProgress()

      const jobId = await syncDeployments({
        startDate: this._startDate ? new Date(this._startDate).toISOString() : null,
        endDate: this._endDate ? new Date(this._endDate).toISOString() : null,
        enableStreaming: true
      })

      this._lastBatchId = jobId
      this._startPolling()
    } catch (e) {
      deployErrorHandler(this, LABELS.SYNC_START_FAILED_MSG, e)
      this._isLoading = false
    }
  }
}