import { LightningElement, api } from 'lwc';

export default class DeployHeader extends LightningElement {
    @api title;
    @api subtitle;
    @api iconName;
    @api alternativeText;
}