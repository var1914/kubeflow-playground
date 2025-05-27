# complete_example.py
import kfp
from kfp import dsl, compiler
from kfp.dsl import component, Input, Output, Dataset

from data_prep_component import prepare_data
from train_component import train_model
from eval_component import evaluate_model

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
    
    # Run pipeline
    client = kfp.Client(host='http://localhost:58727')
    experiment = client.create_experiment('iris-classification')
    
    run = client.create_run_from_pipeline_package(
        './simple_ml_pipeline.yaml',
        arguments={'model_type': 'random_forest'},
    )
    
    print(f"Pipeline submitted! Run ID: {run.run_id}")
    print("Visit http://localhost:58727 to see the pipeline execution")