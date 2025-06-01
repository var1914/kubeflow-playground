from kfp import dsl
from kfp.dsl import component, Input, Output, Dataset, Model

# eval_component.py
@component(
    base_image="python:3.10",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def evaluate_model(
    dataset_input: Input[Dataset],
    model_input: Input[Model]  # Changed to Model type
) -> float:
    import pandas as pd
    from sklearn.metrics import accuracy_score
    import joblib
    import os
    
    print(f"Dataset input path: {dataset_input.path}")
    print(f"Model input path: {model_input.path}")
    
    # Find the test data - check multiple possible locations
    test_csv_paths = [
        f"{dataset_input.path}/test.csv",
        f"{dataset_input.path}_data/test.csv"
    ]
    
    test_csv_path = None
    for path in test_csv_paths:
        if os.path.exists(path):
            test_csv_path = path
            break
    
    if not test_csv_path:
        print("Available paths in dataset:")
        if os.path.exists(dataset_input.path):
            if os.path.isdir(dataset_input.path):
                print(f"Contents of {dataset_input.path}: {os.listdir(dataset_input.path)}")
            else:
                print(f"{dataset_input.path} is a file, not a directory")
        else:
            print(f"{dataset_input.path} doesn't exist")
        raise FileNotFoundError(f"Test data not found in any of: {test_csv_paths}")
    
    print(f"Loading test data from: {test_csv_path}")
    test_df = pd.read_csv(test_csv_path)
    X_test = test_df.drop('target', axis=1)
    y_test = test_df['target']
    
    # Load model
    print(f"Loading model from: {model_input.path}")
    if not os.path.exists(model_input.path):
        print(f"Model file not found at {model_input.path}")
        # Check if it's in a subdirectory
        if os.path.isdir(model_input.path):
            print(f"Model path is a directory. Contents: {os.listdir(model_input.path)}")
        raise FileNotFoundError(f"Model not found at {model_input.path}")
    
    model = joblib.load(model_input.path)
    
    # Evaluate
    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    
    print(f"Test accuracy: {accuracy:.3f}")
    return accuracy