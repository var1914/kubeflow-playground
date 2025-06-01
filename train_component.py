# train_component.py
from kfp import dsl
from kfp.dsl import component, Input, Output, Dataset, Model

@component(
    base_image="python:3.10",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def train_model(
    dataset_input: Input[Dataset],
    model_output: Output[Model],  # Changed to Model type
    model_name: str = "random_forest"
) -> None:
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    import joblib
    import os
    
    print(f"Dataset input path: {dataset_input.path}")
    print(f"Model output path: {model_output.path}")
    
    # Load training data
    train_csv_path = f"{dataset_input.path}/train.csv"
    print(f"Looking for training data at: {train_csv_path}")
    
    if not os.path.exists(train_csv_path):
        print(f"Training file not found at {train_csv_path}")
        print(f"Contents of {dataset_input.path}:")
        if os.path.exists(dataset_input.path):
            print(os.listdir(dataset_input.path))
        else:
            print("Dataset input path doesn't exist!")
        raise FileNotFoundError(f"Training data not found at {train_csv_path}")
    
    train_df = pd.read_csv(train_csv_path)
    X_train = train_df.drop('target', axis=1)
    y_train = train_df['target']
    
    # Train model
    if model_name == "random_forest":
        model = RandomForestClassifier(n_estimators=100, random_state=42)
    else:
        model = LogisticRegression(random_state=42, max_iter=200)
    
    model.fit(X_train, y_train)
    
    # Save model - ensure directory exists
    os.makedirs(os.path.dirname(model_output.path), exist_ok=True)
    joblib.dump(model, model_output.path)  # Save directly to the path, not as subdirectory
    
    print(f"Model {model_name} trained successfully")
    print(f"Training accuracy: {model.score(X_train, y_train):.3f}")
    print(f"Model saved to: {model_output.path}")