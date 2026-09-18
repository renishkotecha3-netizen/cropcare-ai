import re

REFERENCE_URL = 'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/late-blight'


def readable(label):
    return re.sub(r'_+', ' ', label).replace('Pottassium', 'Potassium').strip()


def category_for(label):
    s = label.lower()
    if 'healthy' in s:
        return 'healthy'
    if 'deficiency' in s:
        return 'nutrition'
    if any(x in s for x in ['virus', 'viral']):
        return 'viral'
    if any(x in s for x in ['bacteria', 'soft_rot']):
        return 'bacterial'
    if any(x in s for x in ['pest', 'miner', 'mite', 'nematode']):
        return 'pest'
    if any(x in s for x in ['blight', 'fung', 'mold', 'mildew', 'septoria', 'target', 'shot_hole', 'phytopthora']):
        return 'fungal'
    return 'unknown'


def guidance(label, status):
    if status == 'uncertain':
        return ['Retake a sharp photo of one leaf in natural light, with both affected and healthy areas visible.',
                'Select the correct crop. Ask a local agricultural expert if symptoms continue; this result is inconclusive.']
    c = category_for(label)
    if c == 'healthy':
        return ['No clear problem was identified in this image. Continue checking the whole plant.',
                'Water at soil level, maintain airflow and monitor new growth.']
    actions = {
        'nutrition': ['Check soil or leaf nutrients before adding fertilizer; similar symptoms can have other causes.',
                      'Match any nutrient correction to a soil test and local crop advice.'],
        'viral': ['Inspect for insects and avoid transferring sap between plants on hands or tools.',
                  'Seek local confirmation before removing plants. Fungicides do not cure viral disease.'],
        'bacterial': ['Avoid handling wet plants and splashing irrigation water between plants.',
                      'Clean tools and ask an agricultural expert to confirm the cause before choosing treatment.'],
        'pest': ['Inspect the underside of leaves for insects, mites, eggs or mines.',
                 'Identify the pest before choosing targeted management; preserve beneficial insects.'],
        'fungal': ['Improve airflow, water at soil level and avoid moving wet foliage between plants.',
                   'Confirm the suspected disease locally before selecting a crop-approved treatment.'],
        'unknown': ['Check the plant and surrounding plants for symptoms and obtain an expert diagnosis.'],
    }
    result = actions.get(c, actions['unknown']).copy()
    if 'late_blight' in label.lower() or 'phytopthora' in label.lower():
        result.append('Suspected late blight needs prompt local advice, especially during cool, wet conditions.')
    result.append('Do not copy a neighbour’s pesticide or dose. Follow locally approved product labels and expert advice.')
    return result
