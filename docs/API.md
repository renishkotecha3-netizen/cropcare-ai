# API contract

Base: `http://127.0.0.1:8000/api` in development. All endpoints except health, registration and login require `Authorization: Bearer <token>`. Sessions expire after 30 days, are stored hashed on the server, and are revocable. Flutter stores the raw session token in the device's secure storage.

| Method | Route | Body / purpose |
| --- | --- | --- |
| GET | `/health/` | Service availability; does not run the model |
| POST | `/auth/register/` | JSON `email`, `full_name`, `password`; returns `token`, `user` |
| POST | `/auth/login/` | JSON `email`, `password`; returns `token`, `user` |
| POST | `/auth/logout/` | Optional `device_token`; revokes current session |
| POST | `/auth/password/` | `current_password`, `new_password`; revokes all sessions and returns a new token |
| GET / PATCH | `/profile/` | Own farm/profile and sharing preferences |
| POST | `/scans/` | Multipart `image`, `crop` (`Auto`, `Tomato`, `Potato`, `Pepper`), optional `notes`, `parent_id` |
| GET | `/scans/` | Own history; `page`, `status`, `search` query options |
| GET / PATCH / DELETE | `/scans/{uuid}/` | Read/delete own scan; patch only `outcome` and `notes` |
| GET | `/scans/{uuid}/image/` | Authenticated JPEG bytes for owner only |
| GET | `/reminders/` | Upcoming/uncompleted reminders for local scheduling; also materializes overdue notices |
| GET | `/notifications/` | Own paginated inbox, newest first |
| POST | `/notifications/{uuid}/read/` | Mark own notification read |
| GET | `/nearby/` | Anonymous nearby report summaries using saved farm location |
| GET | `/weather/` | Local weather and general rule-based advice |
| POST / DELETE | `/devices/` | `token`: register/unregister optional Firebase device token |

List pages contain `count`, `next`, `previous`, `results`; the default page size is 20. The nearby and reminder endpoints return unpaginated summary envelopes; local reminder synchronization is limited to the earliest 60 pending checks to respect device scheduling limits.

Profile fields: `full_name`, `farm_name`, `village`, `latitude`, `longitude`, `share_reports`, `nearby_alerts`, `alert_radius_km` (1–50). Both coordinates must be supplied or cleared together. Email and user ID are read-only.

Successful scan response fields include `id`, protected `image_url`, `crop`, `predicted_label`, `condition`, `confidence` (0–100), `status`, `category`, `recommendations`, `alternatives`, `notes`, `created_at`, `follow_up_due`, `follow_up_done`, `parent_id`, `outcome`, `shared`.

`status`: `healthy`, `issue`, `uncertain`. `outcome`: `open`, `improved`, `unchanged`, `worse`, `resolved`. Outcome is the farmer's observation, not a clinical or agronomic confirmation. Top-three confidence values are model scores and are not renormalized to sum to 100.

Uploads must be JPEG/PNG/WebP, at most 8 MB and 20 megapixels, and at least 64 pixels on each dimension. The server decodes the image, corrects orientation, strips metadata and stores a JPEG up to 2048 pixels. Files are never served via a public media URL.

Errors use HTTP 400 for validation, 401 for authentication, 404 for absent/inaccessible owned objects, 429 for request limits, and 503 when model loading is unavailable. Weather provider failures return a `status: unavailable` envelope without fabricated measurements. Missing saved location returns `status: location_required`.

## Scan request example (Windows Command Prompt)

```bat
curl -X POST http://127.0.0.1:8000/api/scans/ ^
  -H "Authorization: Bearer YOUR_TOKEN" ^
  -F "image=@C:/photos/leaf.jpg" ^
  -F "crop=Tomato" ^
  -F "notes=Spots first noticed yesterday"
```

The backend tests use controlled predictions to test workflow outcomes, while `check_model` separately loads and executes the real model. No mock-prediction mode is available in the application.
