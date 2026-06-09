# HrLeaveRequests

> ✅ `200 OK` `GET` https://e.e-statee.com/api/v1/system-user/hr/leave-requests — 1.55s

**Method:** `GET`  
**URL:** `https://e.e-statee.com/api/v1/system-user/hr/leave-requests`  
**Status:** ✅ `200 OK`  
**Sent:** `2026-06-09 21:55:54.919`  
**Received:** `2026-06-09 21:55:56.475`  
**Duration:** `1.55s`

## Request

### Headers

```http
Accept: application/json
x-api-key: d0b3aeb3-1e25-4a6e-b7f8-55e4ccc83d75
x-secret-key: JtWoZQwRDww6NUxASOnOzOWcS0RqB0Nh
Authorization: Bearer Bearer 8|wfSdZf3hPnBTMaGuDfkXZLaYVH8cZuwCNBBjOxLM4066bfa1
```

### Query Parameters

_(none)_

### Body

_(none)_

## Response

```json
{
  "status": true,
  "message": "تمت العملية بنجاح",
  "response": {
    "data": [
      {
        "id": 7,
        "user_id": 20,
        "leave_type_id": 1,
        "leave_allocation_id": null,
        "start_date": "2026-06-09T21:00:00.000000Z",
        "end_date": "2026-06-25T21:00:00.000000Z",
        "total_days": "17.0",
        "status": "pending",
        "status_text": "قيد الانتظار",
        "reason": "فسقف",
        "rejection_reason": null,
        "commissioner_user_id": 2,
        "approved_at": null,
        "rejected_at": null,
        "created_at": "2026-06-09T08:00:36.000000Z",
        "leave_type": {
          "id": 1,
          "name": "مرضي",
          "default_days_per_year": 22,
          "is_paid": true,
          "requires_attachment": false,
          "max_consecutive_days": null
        },
        "commissioner_user": {
          "id": 2,
          "name": "مدير النظام",
          "email": "support@e-statee.com",
          "phone": "+966563742968",
          "avatar_url": "https://e.e-statee.com/default_image/avatar.jpg"
        },
        "approved_by": null,
        "rejected_by": null
      },
      {
        "id": 4,
        "user_id": 20,
        "leave_type_id": 2,
        "leave_allocation_id": null,
        "start_date": "2026-06-10T21:00:00.000000Z",
        "end_date": "2026-06-17T21:00:00.000000Z",
        "total_days": "8.0",
        "status": "approved",
        "status_text": "موافق عليه",
        "reason": "اجتازوا",
        "rejection_reason": null,
        "commissioner_user_id": 2,
        "approved_at": "2026-06-07T15:37:38.000000Z",
        "rejected_at": null,
        "created_at": "2026-06-04T09:51:07.000000Z",
        "leave_type": {
          "id": 2,
          "name": "إجازة سنوية",
          "default_days_per_year": 30,
          "is_paid": true,
          "requires_attachment": false,
          "max_consecutive_days": 4
        },
        "commissioner_user": {
          "id": 2,
          "name": "مدير النظام",
          "email": "support@e-statee.com",
          "phone": "+966563742968",
          "avatar_url": "https://e.e-statee.com/default_image/avatar.jpg"
        },
        "approved_by": {
          "id": 170,
          "name": "عبدالرحمن خالد",
          "email": "abdelrahmankhaleddev@gmail.com",
          "phone": null,
          "avatar_url": "https://e.e-statee.com/default_image/avatar.jpg"
        },
        "rejected_by": null
      },
      {
        "id": 2,
        "user_id": 20,
        "leave_type_id": 1,
        "leave_allocation_id": 1,
        "start_date": "2026-06-09T21:00:00.000000Z",
        "end_date": "2026-06-11T21:00:00.000000Z",
        "total_days": "3.0",
        "status": "approved",
        "status_text": "موافق عليه",
        "reason": "إجازة سنوية",
        "rejection_reason": null,
        "commissioner_user_id": 5,
        "approved_at": "2026-06-04T09:55:41.000000Z",
        "rejected_at": null,
        "created_at": "2026-06-04T08:51:45.000000Z",
        "leave_type": {
          "id": 1,
          "name": "مرضي",
          "default_days_per_year": 22,
          "is_paid": true,
          "requires_attachment": false,
          "max_consecutive_days": null
        },
        "commissioner_user": {
          "id": 5,
          "name": "ميمونة",
          "email": "may.tarif@gmail.com",
          "phone": "+966568330847",
          "avatar_url": "https://e.e-statee.com/default_image/avatar.jpg"
        },
        "approved_by": {
          "id": 20,
          "name": "عبد الرحمن",
          "email": "abdulrahmanhawass@gmail.com",
          "phone": "+201095052738",
          "avatar_url": "https://e.e-statee.com/default_image/avatar.jpg"
        },
        "rejected_by": null
      }
    ],
    "links": {
      "first": "https://e.e-statee.com/api/v1/system-user/hr/leave-requests?page=1",
      "last": "https://e.e-statee.com/api/v1/system-user/hr/leave-requests?page=1",
      "prev": null,
      "next": null
    },
    "meta": {
      "current_page": 1,
      "from": 1,
      "last_page": 1,
      "links": [
        {
          "url": null,
          "label": "pagination.previous",
          "page": null,
          "active": false
        },
        {
          "url": "https://e.e-statee.com/api/v1/system-user/hr/leave-requests?page=1",
          "label": "1",
          "page": 1,
          "active": true
        },
        {
          "url": null,
          "label": "pagination.next",
          "page": null,
          "active": false
        }
      ],
      "path": "https://e.e-statee.com/api/v1/system-user/hr/leave-requests",
      "per_page": 10,
      "to": 3,
      "total": 3
    }
  }
}
```

## cURL

```bash
curl -X GET 'https://e.e-statee.com/api/v1/system-user/hr/leave-requests' \
  -H 'Accept: application/json' \
  -H 'x-api-key: d0b3aeb3-1e25-4a6e-b7f8-55e4ccc83d75' \
  -H 'x-secret-key: JtWoZQwRDww6NUxASOnOzOWcS0RqB0Nh' \
  -H 'Authorization: Bearer Bearer 8|wfSdZf3hPnBTMaGuDfkXZLaYVH8cZuwCNBBjOxLM4066bfa1'
```

## Resend

Re-run this exact request and overwrite this file with the fresh response:

```bash
api2dart resend 'get_hr_leave_requests_action.md'
```

<!-- api2dart:request {"requestName":"HrLeaveRequests","requestMethod":"GET","url":"https://e.e-statee.com/api/v1/system-user/hr/leave-requests","headers":{"Accept":"application/json","x-api-key":"d0b3aeb3-1e25-4a6e-b7f8-55e4ccc83d75","x-secret-key":"JtWoZQwRDww6NUxASOnOzOWcS0RqB0Nh","Authorization":"Bearer Bearer 8|wfSdZf3hPnBTMaGuDfkXZLaYVH8cZuwCNBBjOxLM4066bfa1"},"queryParameters":{},"requestBody":null} -->
