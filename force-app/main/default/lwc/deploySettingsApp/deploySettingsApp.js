import { LightningElement, track } from 'lwc';
import hasDeployAppAccess from '@salesforce/apex/DeployCoreUtils.hasDeployAppAccess';

export default class DeploySettingsApp extends LightningElement {

  @track selectedItem = 'sync';
  hasAccess = false;
  accessChecked = false;

  get isSyncView() {
    return this.selectedItem === 'sync';
  }

  get isScheduleView() {
    return this.selectedItem === 'schedule';
  }

  get isAdvancedView() {
    return this.selectedItem === 'advanced';
  }

  get navSectionLabel() {
    return 'Lug Deploy Tracker';
  }

  get syncLabel() {
    return 'Synchronization';
  }

  get scheduleLabel() {
    return 'Schedule';
  }

  get advancedLabel() {
    return 'Advanced Options';
  }

  get accessDeniedTitle() {
    return 'Access Restricted';
  }

  get accessDeniedMessage() {
    return 'You do not have the necessary permissions to access this application.';
  }

  connectedCallback() {
    this.checkAccess();
  }

  handleSelect(event) {
    this.selectedItem = event.detail.name;
  }

  async checkAccess() {
    try {
      this.hasAccess = await hasDeployAppAccess();
    } catch (err) {
      console.error('Error checking access permission:', err);
    } finally {
      this.accessChecked = true;
    }
  }
}