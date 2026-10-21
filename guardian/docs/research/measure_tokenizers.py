"""Tokenizer fragmentation on everyday English / Roman Urdu / Urdu-script chat.

Run:  set HF_HOME=D:/dev/hf && python -X utf8 measure_tokenizers.py
Downloads tokenizer files only (never model weights).
"""
import os, sys, statistics as st
sys.stdout.reconfigure(encoding="utf-8")
os.environ.setdefault("HF_HOME", r"D:\dev\hf")
from transformers import AutoTokenizer

TOKENIZERS = {
    "xlm-roberta-base": "FacebookAI/xlm-roberta-base",
    "mdeberta-v3-base": "microsoft/mdeberta-v3-base",
    "Qwen3-0.6B": "Qwen/Qwen3-0.6B",
    "Qwen3Guard-Gen-0.6B": "Qwen/Qwen3Guard-Gen-0.6B",
    "byt5-small (bytes)": "google/byt5-small",
    "bert-base-multilingual-cased": "bert-base-multilingual-cased",
}

SENTENCES = {
"English": [
"My exam is on Monday and I have not opened the book yet.",
"Traffic on the main road was terrible again this morning.",
"Did you watch the cricket match last night? What a finish.",
"Mom is asking when you are coming home for dinner.",
"The boss wants the report by five, no idea how.",
"Biryani from that place near the office is honestly the best.",
"My phone battery dies by noon, I need a new one.",
"Can you send me the notes for chapter four?",
"The bus was so late I missed the first lecture.",
"We lost the match because our bowling was awful.",
"My cousin's wedding is next week and I have nothing to wear.",
"Work from home is fine but the internet keeps dropping.",
"Chai without sugar is just sad hot water.",
"Why does this app crash every time I open it?",
"Stop being so lazy and finish your assignment.",
"Honestly your driving is scary, slow down.",
"Shut up, you have no idea what you are talking about.",
"The teacher gave us a surprise quiz, everyone failed.",
"Petrol prices went up again, this is ridiculous.",
"Let's meet at the chai dhaba after work.",
],
"Roman Urdu": [
"Kal mera paper hai aur maine abhi tak kuch parha nahi.",
"Aaj phir road pe itna traffic tha, ek ghanta lag gaya.",
"Match dekha kal raat? Last over mein kya khel hua.",
"Ammi pooch rahi hain tum khaane pe kab aa rahe ho.",
"Boss ko report paanch baje tak chahiye, pata nahi kaise hogi.",
"Office ke paas wali biryani sach mein sab se behtar hai.",
"Mera phone dopahar tak hi band ho jata hai, naya lena parega.",
"Chapter four ke notes bhej do yaar.",
"Bus itni late thi ke pehla lecture miss ho gaya.",
"Hum match haar gaye kyunke bowling bohat buri thi.",
"Agle hafte cousin ki shadi hai aur pehnne ko kuch nahi.",
"Ghar se kaam theek hai lekin net baar baar chala jata hai.",
"Cheeni ke baghair chai bas garam paani hai.",
"Ye app har dafa kholte hi band kyun ho jati hai?",
"Itne sust mat bano, apna assignment khatam karo.",
"Sach mein tumhari driving se dar lagta hai, aahista chalao.",
"Chup karo, tumhe kuch pata nahi tum kya bol rahe ho.",
"Teacher ne surprise quiz le liya, sab fail ho gaye.",
"Petrol phir mehnga ho gaya, ye to hadd hai.",
"Kaam ke baad chai ke dhabe pe milte hain.",
],
"Urdu script": [
"کل میرا پرچہ ہے اور میں نے ابھی تک کچھ نہیں پڑھا۔",
"آج پھر سڑک پر اتنا ٹریفک تھا کہ ایک گھنٹہ لگ گیا۔",
"کل رات میچ دیکھا؟ آخری اوور میں کیا کھیل ہوا۔",
"امی پوچھ رہی ہیں تم کھانے پر کب آ رہے ہو۔",
"باس کو رپورٹ پانچ بجے تک چاہیے، پتہ نہیں کیسے ہوگی۔",
"دفتر کے پاس والی بریانی سچ میں سب سے بہتر ہے۔",
"میرا فون دوپہر تک ہی بند ہو جاتا ہے، نیا لینا پڑے گا۔",
"چوتھے باب کے نوٹس بھیج دو یار۔",
"بس اتنی لیٹ تھی کہ پہلا لیکچر چھوٹ گیا۔",
"ہم میچ ہار گئے کیونکہ بولنگ بہت بری تھی۔",
"اگلے ہفتے کزن کی شادی ہے اور پہننے کو کچھ نہیں۔",
"گھر سے کام ٹھیک ہے لیکن نیٹ بار بار چلا جاتا ہے۔",
"چینی کے بغیر چائے بس گرم پانی ہے۔",
"یہ ایپ ہر دفعہ کھولتے ہی بند کیوں ہو جاتی ہے؟",
"اتنے سست مت بنو، اپنا کام ختم کرو۔",
"سچ میں تمہاری ڈرائیونگ سے ڈر لگتا ہے، آہستہ چلاؤ۔",
"چپ کرو، تمہیں کچھ پتہ نہیں تم کیا بول رہے ہو۔",
"ٹیچر نے اچانک کوئز لے لیا، سب فیل ہو گئے۔",
"پیٹرول پھر مہنگا ہو گیا، یہ تو حد ہے۔",
"کام کے بعد چائے کے ڈھابے پر ملتے ہیں۔",
],
}
for v in SENTENCES.values():
    assert len(v) == 20, "exactly 20 sentences per form"

def measure(tok, sents):
    n_tok, per_word, split3, single, words, unk = [], [], 0, 0, 0, 0
    unk_id = tok.unk_token_id
    for s in sents:
        ids = tok(s, add_special_tokens=False)["input_ids"]
        n_tok.append(len(ids))
        unk += sum(1 for i in ids if unk_id is not None and i == unk_id)
        for w in s.split():
            wids = tok(w, add_special_tokens=False)["input_ids"]
            words += 1
            per_word.append(len(wids))
            if len(wids) >= 3:
                split3 += 1
            # single-char token: decoded piece has exactly one non-marker char
            for p in tok.convert_ids_to_tokens(wids):
                core = p.replace("▁", "").replace("##", "").replace("Ġ", "")
                if len(core) == 1:
                    single += 1
    total = sum(per_word)
    return dict(tok_per_sent=st.mean(n_tok), tok_per_word=total / words,
                pct_split3=100 * split3 / words, pct_single=100 * single / total,
                unk=unk)

rows = []
for name, repo in TOKENIZERS.items():
    try:
        tok = AutoTokenizer.from_pretrained(repo)
    except Exception as e:  # gated/missing: report and continue
        print(f"SKIP {name}: {type(e).__name__}: {str(e)[:120]}")
        continue
    for form, sents in SENTENCES.items():
        m = measure(tok, sents)
        rows.append((name, form, m))
        # byte fallback check on Urdu: Qwen (byte-level BPE) never emits <unk>; show the pieces of one word
    if form == "Urdu script":
        print(f"  {name} pieces for 'بریانی': {tok.tokenize('بریانی')}  vocab={len(tok)}")

print("\n| tokenizer | form | tok/sent | tok/word | % words 3+ pieces | % single-char tokens | <unk> |")
print("|---|---|---|---|---|---|---|")
for name, form, m in rows:
    print(f"| {name} | {form} | {m['tok_per_sent']:.1f} | {m['tok_per_word']:.2f} | "
          f"{m['pct_split3']:.0f} | {m['pct_single']:.0f} | {m['unk']} |")
