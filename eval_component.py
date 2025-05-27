from kfp import dsl
from kfp.dsl import component, Input, Output, Dataset, Metrics

# eval_component.py
@component(
    base_image="python:3.10",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def evaluate_model(
    dataset_input: Input[Dataset],
    model_input: Input[Dataset],
    metrics_output: Output[Metrics]  # Add proper output parameter
) -> None:  # Return None since we're using Output parameter
    import pandas as pd
    from sklearn.metrics import accuracy_score
    import joblib
    import json
    
    # Load test data and model
    test_df = pd.read_csv(f"{dataset_input.path}/test.csv")
    X_test = test_df.drop('target', axis=1)
    y_test = test_df['target']
    
    model = joblib.load(f"{model_input.path}/model.pkl")
    
    # Evaluate
    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    
    print(f"Test accuracy: {accuracy:.3f}")
    
    # Save metrics to output
    metrics = {
        "accuracy": accuracy,
        "test_samples": len(y_test)
    }
    
    with open(f"{metrics_output.path}/metrics.json", "w") as f:
        json.dump(metrics, f)