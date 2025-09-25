/**
 * n8n ACI Tool Executor Node
 * Integrates 600+ ACI tools into n8n workflows
 */

import {
    IExecuteFunctions,
    INodeExecutionData,
    INodeType,
    INodeTypeDescription,
    ILoadOptionsFunctions,
    INodePropertyOptions,
} from 'n8n-workflow';

export class ACIToolExecutor implements INodeType {
    description: INodeTypeDescription = {
        displayName: 'ACI Tool Executor',
        name: 'aciToolExecutor',
        icon: 'file:aci.svg',
        group: ['transform'],
        version: 1,
        description: 'Execute any tool from 600+ ACI integrations',
        defaults: {
            name: 'ACI Tool',
        },
        inputs: ['main'],
        outputs: ['main'],
        credentials: [
            {
                name: 'aciApi',
                required: false,
            },
        ],
        properties: [
            {
                displayName: 'Backend URL',
                name: 'backendUrl',
                type: 'string',
                default: 'http://aci-backend:8000',
                description: 'URL of the self-hosted ACI backend',
            },
            {
                displayName: 'Operation',
                name: 'operation',
                type: 'options',
                options: [
                    {
                        name: 'Execute Tool',
                        value: 'execute',
                        description: 'Execute a specific tool',
                    },
                    {
                        name: 'Search Tools',
                        value: 'search',
                        description: 'Search for relevant tools',
                    },
                    {
                        name: 'List Apps',
                        value: 'listApps',
                        description: 'List all available apps',
                    },
                    {
                        name: 'Dynamic Workflow',
                        value: 'dynamic',
                        description: 'Build dynamic workflow from description',
                    },
                ],
                default: 'execute',
            },
            {
                displayName: 'App Name',
                name: 'appName',
                type: 'options',
                typeOptions: {
                    loadOptionsMethod: 'getApps',
                },
                default: '',
                required: true,
                displayOptions: {
                    show: {
                        operation: ['execute'],
                    },
                },
                description: 'Select the app containing the tool',
            },
            {
                displayName: 'Function Name',
                name: 'functionName',
                type: 'options',
                typeOptions: {
                    loadOptionsMethod: 'getFunctions',
                    loadOptionsDependsOn: ['appName'],
                },
                default: '',
                required: true,
                displayOptions: {
                    show: {
                        operation: ['execute'],
                    },
                },
                description: 'Select the function to execute',
            },
            {
                displayName: 'Parameters',
                name: 'parameters',
                type: 'json',
                default: '{}',
                displayOptions: {
                    show: {
                        operation: ['execute'],
                    },
                },
                description: 'JSON parameters for the tool execution',
            },
            {
                displayName: 'Search Query',
                name: 'searchQuery',
                type: 'string',
                default: '',
                displayOptions: {
                    show: {
                        operation: ['search'],
                    },
                },
                description: 'Search for relevant tools',
            },
            {
                displayName: 'Workflow Description',
                name: 'workflowDescription',
                type: 'string',
                typeOptions: {
                    rows: 5,
                },
                default: '',
                displayOptions: {
                    show: {
                        operation: ['dynamic'],
                    },
                },
                description: 'Describe the workflow you want to build',
            },
        ],
    };

    methods = {
        loadOptions: {
            async getApps(this: ILoadOptionsFunctions): Promise<INodePropertyOptions[]> {
                const backendUrl = this.getNodeParameter('backendUrl', '') as string;
                
                try {
                    const response = await this.helpers.request({
                        method: 'GET',
                        url: `${backendUrl}/v1/apps`,
                        json: true,
                    });

                    return response.map((app: any) => ({
                        name: app.display_name || app.name,
                        value: app.name,
                        description: app.description,
                    }));
                } catch (error) {
                    console.error('Failed to load apps:', error);
                    return [];
                }
            },

            async getFunctions(this: ILoadOptionsFunctions): Promise<INodePropertyOptions[]> {
                const backendUrl = this.getNodeParameter('backendUrl', '') as string;
                const appName = this.getNodeParameter('appName', '') as string;
                
                if (!appName) {
                    return [];
                }

                try {
                    const response = await this.helpers.request({
                        method: 'GET',
                        url: `${backendUrl}/v1/functions`,
                        qs: { app_name: appName },
                        json: true,
                    });

                    return response.map((func: any) => ({
                        name: func.name,
                        value: func.name,
                        description: func.description || func.summary,
                    }));
                } catch (error) {
                    console.error('Failed to load functions:', error);
                    return [];
                }
            },
        },
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];
        const backendUrl = this.getNodeParameter('backendUrl', 0) as string;
        const operation = this.getNodeParameter('operation', 0) as string;

        for (let i = 0; i < items.length; i++) {
            try {
                let result: any;

                if (operation === 'execute') {
                    // Execute a specific tool
                    const appName = this.getNodeParameter('appName', i) as string;
                    const functionName = this.getNodeParameter('functionName', i) as string;
                    const parameters = this.getNodeParameter('parameters', i) as string;

                    result = await this.helpers.request({
                        method: 'POST',
                        url: `${backendUrl}/v1/functions/execute`,
                        body: {
                            app_name: appName,
                            function_name: functionName,
                            parameters: JSON.parse(parameters),
                        },
                        json: true,
                    });

                } else if (operation === 'search') {
                    // Search for tools
                    const searchQuery = this.getNodeParameter('searchQuery', i) as string;

                    result = await this.helpers.request({
                        method: 'POST',
                        url: `${backendUrl}/v1/functions/search`,
                        body: {
                            query: searchQuery,
                            limit: 10,
                        },
                        json: true,
                    });

                } else if (operation === 'listApps') {
                    // List all available apps
                    result = await this.helpers.request({
                        method: 'GET',
                        url: `${backendUrl}/v1/apps`,
                        json: true,
                    });

                } else if (operation === 'dynamic') {
                    // Build dynamic workflow
                    const workflowDescription = this.getNodeParameter('workflowDescription', i) as string;
                    
                    // First, search for relevant tools
                    const searchResult = await this.helpers.request({
                        method: 'POST',
                        url: `${backendUrl}/v1/functions/search`,
                        body: {
                            query: workflowDescription,
                            limit: 5,
                        },
                        json: true,
                    });

                    // Build workflow steps
                    const workflowSteps = searchResult.map((tool: any, index: number) => ({
                        step: index + 1,
                        app: tool.app_name,
                        function: tool.function_name,
                        description: tool.description,
                        ready: false, // Needs parameter configuration
                    }));

                    result = {
                        description: workflowDescription,
                        suggested_tools: searchResult,
                        workflow_steps: workflowSteps,
                        message: 'Configure parameters for each step to build the workflow',
                    };
                }

                returnData.push({
                    json: result,
                    pairedItem: i,
                });

            } catch (error: any) {
                // Handle errors
                if (this.continueOnFail()) {
                    returnData.push({
                        json: {
                            error: error.message,
                        },
                        pairedItem: i,
                    });
                    continue;
                }
                throw error;
            }
        }

        return [returnData];
    }
}

/**
 * Helper class for building complex ACI workflows
 */
export class ACIWorkflowBuilder {
    private steps: any[] = [];

    addStep(app: string, functionName: string, parameters: any) {
        this.steps.push({
            app,
            function: functionName,
            parameters,
        });
        return this;
    }

    async execute(backendUrl: string): Promise<any[]> {
        const results = [];
        
        for (const step of this.steps) {
            const response = await fetch(`${backendUrl}/v1/functions/execute`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    app_name: step.app,
                    function_name: step.function,
                    parameters: step.parameters,
                }),
            });
            
            results.push(await response.json());
        }
        
        return results;
    }

    /**
     * Example workflow: Deploy from GitHub to Vercel with notifications
     */
    static createDeploymentWorkflow() {
        return new ACIWorkflowBuilder()
            .addStep('github', 'get_repository', { repo: 'user/repo' })
            .addStep('vercel', 'create_deployment', { 
                project: 'my-app',
                git_url: '{{steps.0.clone_url}}' 
            })
            .addStep('slack', 'send_message', {
                channel: '#deployments',
                text: 'Deployment started: {{steps.1.url}}'
            });
    }

    /**
     * Example workflow: Research and document
     */
    static createResearchWorkflow() {
        return new ACIWorkflowBuilder()
            .addStep('brave_search', 'search', { query: '{{input.query}}' })
            .addStep('notion', 'create_page', {
                title: 'Research: {{input.query}}',
                content: '{{steps.0.results}}'
            })
            .addStep('gmail', 'send_email', {
                to: '{{input.email}}',
                subject: 'Research Complete',
                body: 'Your research has been saved to Notion'
            });
    }
}
