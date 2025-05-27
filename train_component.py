# train_component.py
from kfp import dsl
from kfp.dsl import component, Input, Output, Dataset

@component(
    base_image="python:3.8",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def train_model(
    dataset_input: Input[Dataset],
    model_output: Output[Dataset],
    model_name: str = "random_forest"
):
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    import joblib
    
    # Load training data
    train_df = pd.read_csv(f"{dataset_input.path}/train.csv")
    X_train = train_df.drop('target', axis=1)
    y_train = train_df['target']
    
    # Train model
    if model_name == "random_forest":
        model = RandomForestClassifier(n_estimators=100, random_state=42)
    else:
        model = LogisticRegression(random_state=42, max_iter=200)
    
    model.fit(X_train, y_train)
    
    # Save model
    joblib.dump(model, f"{model_output.path}/model.pkl")
    
    print(f"Model {model_name} trained successfully")
    print(f"Training accuracy: {model.score(X_train, y_train):.3f}")