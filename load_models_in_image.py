from transformers import (
    AutoTokenizer, 
    AutoModelForSeq2SeqLM)

# Only t5-small is baked into the image.
# distilbart (~1.2 GB) is a rare fallback and is loaded lazily in src/events.py.
def loading_summ_model():
    SUMMARIZATION_MODEL_NAME_t5 = 't5-small'
    MAX_INPUT_LENGTH = 1024
    print(f"Loading the {SUMMARIZATION_MODEL_NAME_t5} model for summerization")
    summarization_tokenizer_t5 = AutoTokenizer.from_pretrained(SUMMARIZATION_MODEL_NAME_t5, model_max_length=MAX_INPUT_LENGTH)
    summarization_model_t5 = AutoModelForSeq2SeqLM.from_pretrained(SUMMARIZATION_MODEL_NAME_t5)    
    return(summarization_tokenizer_t5,summarization_model_t5)

summarization_tokenizer_t5, summarization_model_t5 = loading_summ_model()
