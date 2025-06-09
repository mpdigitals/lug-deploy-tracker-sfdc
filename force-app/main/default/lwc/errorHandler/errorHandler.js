import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * Standard error handler for LWC components.
 *
 * @param {LightningElement} component  – use `this` from the caller.
 * @param {string}           contextMsg – short context message.
 * @param {any}              error      – Apex or JS error object.
 */
export default function errorHandler(component, contextMsg, error) {
    const message =
        error?.body?.message ??
        error?.message ??
        'Unexpected error';

    component.dispatchEvent(
        new ShowToastEvent({
            title:  'Error',
            message: `${contextMsg}: ${message}`,
            variant: 'error',
            mode:    'sticky'
        })
    );
}