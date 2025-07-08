import { showToast } from 'c/deployToastService';

export default function deployErrorHandler(component, title, error) {
    console.error(title, error);

    let message = 'Unknown error';

    if (error) {
        if (typeof error === 'string') {
            message = error;
        } else if (error.body && error.body.message) {
            message = error.body.message;
        } else if (error.message) {
            message = error.message;
        }
    }

    showToast(component, {
        title,
        message,
        variant: 'error',
        mode: 'sticky'
    });
}