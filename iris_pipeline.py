# complete_example.py
import kfp
from kfp import dsl, compiler
from kfp.dsl import component, Input, Output, Dataset

from data_prep_component import prepare_data
from train_component import train_model
from eval_component import evaluate_model
from kfp_client_manager import KFPClientManager

# Pipeline definition
@dsl.pipeline(
    name="simple-ml-pipeline",
    description="A simple ML pipeline for iris classification"
)
def simple_ml_pipeline(model_type: str = "random_forest") -> None:
    data_prep_task = prepare_data()
    train_task = train_model(
        dataset_input=data_prep_task.outputs['dataset_output'],
        model_name=model_type
    )
    eval_task = evaluate_model(
        dataset_input=data_prep_task.outputs['dataset_output'],
        model_input=train_task.outputs['model_output']
    )
    
    # Don't return anything - just let the pipeline run

if __name__ == "__main__":
    # Compile pipeline
    compiler.Compiler().compile(
        pipeline_func=simple_ml_pipeline,
        package_path='simple_ml_pipeline.yaml'
    )
    
    # initialize a KFPClientManager
    kfp_client_manager = KFPClientManager(
        api_url="http://localhost:56291/pipeline",
        skip_tls_verify=True,

        dex_username="user@example.com",
        dex_password="12341234",

        # can be 'ldap' or 'local' depending on your Dex configuration
        dex_auth_type="local",
    )

    # get a newly authenticated KFP client
    # TIP: long-lived sessions might need to get a new client when their session expires
    kfp_client = kfp_client_manager.create_kfp_client()

    # test the client by listing experiments
    experiments = kfp_client.create_experiment(
        name='iris-classification',
        description='Experiment for Iris classification using a simple ML pipeline',
        namespace='kubeflow-user-example-com'
    )
    # Run pipeline    
    run = kfp_client.create_run_from_pipeline_package(
        './simple_ml_pipeline.yaml',
        arguments={'model_type': 'random_forest'},
        experiment_name ='iris-classification',
        namespace='kubeflow-user-example-com'
    )
    
    print(f"Pipeline submitted! Run ID: {run.run_id}")
    print("Visit http://localhost:56291 to see the pipeline execution")