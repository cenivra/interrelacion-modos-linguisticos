# python/embeddings_setup.py
"""
Módulo para la generación de embeddings semánticos.
Utiliza Sentence Transformers y el modelo paraphrase-multilingual-MiniLM-L12-v2.
"""

import numpy as np
from sentence_transformers import SentenceTransformer
import torch
import os
import json

# --- Carga del modelo ---
MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
EMBEDDING_DIM = 384

# Cargar modelo (se descarga automáticamente la primera vez)
model = SentenceTransformer(MODEL_NAME)

# Configuración de dispositivo (GPU si está disponible)
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)

# --- Función de codificación ---
def encode_texts(texts, normalize=True, batch_size=32):
    """
    Codifica una lista de textos en embeddings.

    Args:
        texts (list of str): Lista de textos.
        normalize (bool): Si es True, normaliza los embeddings a norma L2.
        batch_size (int): Tamaño de lote para la codificación.

    Returns:
        np.ndarray: Matriz de embeddings de forma (len(texts), EMBEDDING_DIM).
    """
    if not isinstance(texts, list):
        raise TypeError("texts debe ser una lista de cadenas")
    # Reemplazar textos vacíos o None por placeholder
    texts_processed = []
    for t in texts:
        if t is None or not isinstance(t, str) or t.strip() == "":
            texts_processed.append("[VACÍO]")
        else:
            texts_processed.append(t)
    # Codificar
    embeddings = model.encode(
        texts_processed,
        normalize_embeddings=normalize,
        batch_size=batch_size,
        show_progress_bar=False,
        convert_to_numpy=True
    )
    # Asegurar dimensiones
    if embeddings.ndim == 1:
        embeddings = embeddings.reshape(1, -1)
    return embeddings.astype(np.float64)

# --- Función de metadatos ---
def get_model_info():
    """
    Devuelve información sobre el modelo y el entorno.
    """
    import sentence_transformers
    import torch
    info = {
        "model_name": MODEL_NAME,
        "embedding_dim": EMBEDDING_DIM,
        "sentence_transformers_version": sentence_transformers.__version__,
        "torch_version": torch.__version__,
        "device": str(device),
        "normalization": "L2" if True else "None",  # se puede parametrizar
    }
    return info

# Si se ejecuta directamente, muestra la información
if __name__ == "__main__":
    print(get_model_info())