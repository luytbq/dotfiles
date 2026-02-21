open_ai_improve_english() {
    text="$(cat)"

    # Use jq to properly escape the text for JSON
    json_payload=$(jq -n \
        --arg text "$text" \
        '{
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "You are an English teacher evaluating and improving student writing. Analyze the text and respond in EXACTLY this format:

SCORES:
Grammar: [0-100]
Vocabulary: [0-100]
Style: [0-100]
Overall: [0-100]

GRAMMAR ISSUES:
- [issue]: [correction and brief explanation]
(or \"None found\" if perfect)

VOCABULARY ISSUES:
- [issue]: [better word choice and explanation]
(or \"None found\" if perfect)

STYLE ISSUES:
- [issue]: [suggestion for improvement]
(or \"None found\" if perfect)

IMPROVED:
[The corrected and improved version of the text - ONLY the improved text, nothing else]

Scoring criteria:
- Grammar: spelling, punctuation, sentence structure, tense, subject-verb agreement
- Vocabulary: word choice, precision, avoiding repetition, appropriate register
- Style: clarity, flow, conciseness, readability, sentence variety

IMPORTANT: The IMPROVED section must contain ONLY the corrected text, no explanations or notes."},
                {"role": "user", "content": $text}
            ]
        }')

    local response
    response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "Error: $(echo "$response" | jq -r '.error.message')" >&2
        return 1
    fi

    echo "$response" | jq -r '.choices[0].message.content'
}

open_ai_summarize() {
    text="$(cat)"

    # Use jq to properly escape the text for JSON
    json_payload=$(jq -n \
        --arg text "$text" \
        '{
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "Summarize the following text concisely, capturing the key points in a clear and brief manner."},
                {"role": "user", "content": $text}
            ]
        }')

    local response
    response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "Error: $(echo "$response" | jq -r '.error.message')" >&2
        return 1
    fi

    echo "$response" | jq -r '.choices[0].message.content'
}

open_ai_translate_vi_en() {
    text="$(cat)"

    # Use jq to properly escape the text for JSON
    json_payload=$(jq -n \
        --arg text "$text" \
        '{
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "Translate the following Vietnamese text to English. Provide only the translation, no explanations."},
                {"role": "user", "content": $text}
            ]
        }')

    local response
    response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "Error: $(echo "$response" | jq -r '.error.message')" >&2
        return 1
    fi

    echo "$response" | jq -r '.choices[0].message.content'
}

open_ai_translate_en_vi() {
    text="$(cat)"

    # Use jq to properly escape the text for JSON
    json_payload=$(jq -n \
        --arg text "$text" \
        '{
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "Translate the following English text to Vietnamese. Provide only the translation, no explanations."},
                {"role": "user", "content": $text}
            ]
        }')

    local response
    response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "Error: $(echo "$response" | jq -r '.error.message')" >&2
        return 1
    fi

    echo "$response" | jq -r '.choices[0].message.content'
}

