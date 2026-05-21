# OnBoardingData

> ✅ `200 OK` `GET` https://dev.laiila.net/api/onboarding/data — 529ms

**Method:** `GET`  
**URL:** `https://dev.laiila.net/api/onboarding/data`  
**Status:** ✅ `200 OK`  
**Sent:** `2026-05-21 14:11:51.895`  
**Received:** `2026-05-21 14:11:52.425`  
**Duration:** `529ms`

## Request

### Headers

```http
Accept: application/json
Accept-Language: ar
Authorization: Bearer 8|JXL95mioUfmaQEsrTERjmmOeZPFIPEiVYa4ijwz704318771
```

### Query Parameters

_(none)_

### Body

_(none)_

## Response

```json
{
  "message": "تم تحميل البيانات",
  "data": {
    "onboarding": [
      {
        "id": 1,
        "title": "title ar",
        "description": "description ar",
        "file": "https://dev.laiila.net/default_image/onboarding_temp.png"
      }
    ]
  }
}
```

## cURL

```bash
curl -X GET 'https://dev.laiila.net/api/onboarding/data' \
  -H 'Accept: application/json' \
  -H 'Accept-Language: ar' \
  -H 'Authorization: Bearer 8|JXL95mioUfmaQEsrTERjmmOeZPFIPEiVYa4ijwz704318771'
```
