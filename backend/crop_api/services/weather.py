"""Rule-based weather advice, not a validated disease forecasting model."""
import math
import requests
from django.core.cache import cache
from django.utils import timezone

SOURCE = 'https://open-meteo.com/'


def crop_advice(scan, current):
    wet = current['relative_humidity_2m'] >= 85 or current['precipitation'] > 0
    if scan.category in ['fungal','bacterial'] and wet:
        text = 'Your recent leaf-disease suggestion and wet conditions make careful inspection useful. Keep foliage dry where practical, maintain airflow and seek local confirmation.'
    elif scan.category == 'nutrition':
        text = 'Weather cannot confirm a nutrient deficiency. Check soil moisture and arrange a soil or leaf test before applying nutrients.'
    elif scan.category == 'pest':
        text = 'Inspect leaf undersides and growing tips for pests. Weather alone cannot identify the pest or justify spraying.'
    elif scan.category == 'viral':
        text = 'Check for possible insect vectors and avoid moving sap on tools. A weather change does not confirm recovery from a viral problem.'
    else:
        text = 'Continue checking the plant and compare your next photo. Weather changes cannot confirm whether this condition is present or resolved.'
    return {'condition': scan.condition, 'crop': scan.crop, 'advice': text}


def advisory(current, daily):
    humidity = current['relative_humidity_2m']
    temp = current['temperature_2m']
    rain = daily['precipitation_sum'][0]
    tips = ['Inspect both sides of leaves and water at soil level.']
    if humidity >= 85 and 10 <= temp <= 26:
        tips.append('Cool, humid conditions can favour some leaf diseases. Check susceptible crops more frequently and maintain airflow.')
    if rain >= 2 or current['precipitation'] > 0:
        tips.append('Wet conditions: avoid working among wet plants and check drainage to reduce splash between plants.')
    if current['wind_speed_10m'] >= 15:
        tips.append('Wind is elevated. Check the product label and local guidance before any spraying to avoid drift.')
    if temp >= 32:
        tips.append('Hot conditions: check soil moisture and signs of wilting; heat stress can resemble disease symptoms.')
    tips.append('Weather does not confirm disease. This advice uses general rules, not a validated local outbreak forecast.')
    return tips


def get_weather(lat, lon):
    # Rounded provider coordinates avoid disclosing precise farm coordinates.
    lat, lon = round(lat, 2), round(lon, 2)
    key = f'weather:{lat}:{lon}'
    stored = cache.get(key)
    if stored:
        return stored
    try:
        r = requests.get('https://api.open-meteo.com/v1/forecast', params={
            'latitude': lat, 'longitude': lon, 'timezone': 'UTC', 'forecast_days': 3,
            'current': 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code',
            'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max',
        }, timeout=(3, 8))
        r.raise_for_status()
        data = r.json()
        current, daily = data['current'], data['daily']
        for field in ['temperature_2m', 'relative_humidity_2m', 'precipitation', 'wind_speed_10m']:
            if not math.isfinite(float(current[field])):
                raise ValueError('Invalid weather data')
        for field in ['temperature_2m_max', 'temperature_2m_min', 'precipitation_sum', 'precipitation_probability_max']:
            if len(daily[field]) != len(daily['time']) or not daily[field] or any(v is None or not math.isfinite(float(v)) for v in daily[field]):
                raise ValueError('Missing forecast')
        result = {'status': 'available', 'source': SOURCE, 'attribution': 'Weather data by Open-Meteo (CC BY 4.0)',
                  'fetched_at': timezone.now().isoformat(), 'timezone': 'UTC', 'current': current,
                  'daily': daily, 'advice': advisory(current, daily)}
        cache.set(key, result, 900)
        return result
    except (requests.RequestException, ValueError, KeyError, TypeError, IndexError):
        return {'status': 'unavailable', 'detail': 'Weather is temporarily unavailable. Try again later.', 'source': SOURCE, 'advice': []}
