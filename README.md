OpenBoxes Devops
=================
Infrastracture as Code artifacts for OpenBoxes.

## About

OpenBoxes is an Open Source Inventory and Supply Chain Management System. The initial implementation of OpenBoxes will occur at Partners In Health-supported facilities in Haiti.

## Deploy to your Azure VPC

*Deploy to Azure* button will bring you to Azure portal, where after filling a few of the properties you can get your OpenBoxes environment in a matter of minutes. In the Azure setup screen, look at each property's tooltip description to understand its purpose.

For more information and step-by-step instructions go to:
https://openboxes.atlassian.net/wiki/spaces/OBW/pages/1719435265/Push-button+deployment

*Deploy to Azure* uses the ARM template defined in [openboxes-devops](https://github.com/openboxes/openboxes-devops/tree/master/arm-template) repository.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fopenboxes%2Fopenboxes-devops%2Fmaster%2Farm-template%2Fopenboxes-arm.json)

*Visualize* will open armviz.io to display graph of all of the Azure resources, which the deployment will provision.

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fopenboxes%2Fopenboxes-devops%2Fmaster%2Farm-template%2Fopenboxes-arm.json)
