import { showToast } from 'c/deployToastService';

export default function deployErrorHandler(component, title, error) {
    console.error(title, error);
    const message = (error && error.body && error.body.message)
        ? error.body.message
        : (error && error.message)
            ? error.message
            : 'Unknown error';
    showToast(component, {
        title,
        message,
        variant: 'error',
        mode: 'sticky'
    });
}