import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export function showToast(component, { title, message, variant = 'info', mode = 'dismissable' }) {
    const evt = new ShowToastEvent({ title, message, variant, mode });
    component.dispatchEvent(evt);
}