#!/usr/bin/env bash

WEATHER_ICONS='{
    "0": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Clear Sky"
    },
    "1": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Mainly Clear"
    },
    "2": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Partly Cloud"
    },
    "3": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Overcast"
    },
    "45": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Fog"
    },
    "48": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rime Fog"
    },
    "51": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Drizzle Light"
    },
    "53": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Drizzle Moderate"
    },
    "55": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Drizzle Dense"
    },
    "56": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Frezzing Drizzle Light"
    },
    "57": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Frezzing Drizzle Dense"
    },
    "61": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rain Slight"
    },
    "63": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rain Moderate"
    },
    "65": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rain Heavy"
    },
    "66": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Frezzing Rain Light"
    },
    "67": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Frezzing Rain Heavy"
    },
    "71": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Snow Fall Slight"
    },
    "73": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Snow Fall Moderate"
    },
    "75": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Snow Fall Heavy"
    },
    "77": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Snow Grains"
    },
    "80": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rain Shower Slight"
    },
    "81": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rain Showwer Moderate"
    },
    "82": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Rain Shower Violent"
    },
    "85": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Snow Shower Slight"
    },
    "86": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Snow Shower Heavy"
    },
    "95": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Thunderstorm Slight"
    },
    "96": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Thunderstorm Moderate"
    },
    "99": {
        "icon": "",
        "day_icon": "",
        "night_icon": "",
        "desc": "Thunderstorm Heavy"
    }
}'

# Default Coordinate is Tokyo
LATITUDE="35.6895"
LONGITUDE="139.6917"
URL="https://api.open-meteo.com/v1/forecast"
CURRENT_VARS="temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_gusts_10m,wind_direction_10m,wind_speed_10m"
API_URL="${URL}?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=${CURRENT_VARS}&timezone=auto&forecast_days=1&forecast_hours=1&past_hours=1"
API_RESPONSE=$(curl -s -f "$API_URL")

[[ $? -ne 0 ]] && exit 1

weather_code=$(jq '.current.weather_code' <<<"$API_RESPONSE")

if [ -n "$weather_code" ]; then
    weather_alt=$(jq -c --argjson wc "\"$weather_code\"" '.[$wc]' <<<"$WEATHER_ICONS")
    weather_data=$(jq -c --argjson wa "$weather_alt" '.current.weather_alt = $wa' <<<"$API_RESPONSE")
fi

echo "${weather_data:-$API_RESPONSE}"
