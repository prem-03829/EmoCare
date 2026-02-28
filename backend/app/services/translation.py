#trans;ation
import argostranslate.translate

def translate(text: str, from_lang: str, to_lang: str) -> str:
    installed_languages = argostranslate.translate.get_installed_languages()

    from_lang_obj = next((l for l in installed_languages if l.code == from_lang), None)
    to_lang_obj = next((l for l in installed_languages if l.code == to_lang), None)

    if not from_lang_obj or not to_lang_obj:
        return text  # fallback

    translation = from_lang_obj.get_translation(to_lang_obj)

    if not translation:
        return text  # fallback

    return translation.translate(text)