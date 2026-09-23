# SchoolOS SaaS account layer

This document defines the account layer that sits above individual SchoolOS school tenants.

## Core hierarchy

```text
Person
  ├─ OrganizationMembership
  │    └─ Organization
  │         └─ School(s)
  └─ SchoolMembership
       └─ School tenant + operational role
```

An organization is the commercial/customer account. A school remains the operational tenant.

A person may own or administer an organization and may separately hold different operational roles in its schools. Account ownership must never be inferred from the `proprietor` school role.

## Organization roles

The native app currently understands:

- `owner`
- `administrator` / `admin`
- `billing_administrator` / `billing_admin`

`owner` and `administrator` may create schools. `owner` and `billing_administrator` may manage billing once billing is added.

Unknown organization roles are ignored by older app versions rather than preventing sign-in.

## `GET /api/v1/me/`

Existing `memberships` remain unchanged except for one optional field:

```json
{
  "id": "membership-1",
  "schoolId": "school-1",
  "schoolName": "Al-Madinah Academy",
  "role": "proprietor",
  "organizationId": "org-1"
}
```

`organizationId` is optional during migration so older server payloads and demo data remain compatible.

The profile may now also include account-level memberships:

```json
{
  "id": "person-1",
  "email": "owner@example.com",
  "name": "School Owner",
  "organizations": [
    {
      "id": "org-membership-1",
      "organizationId": "org-1",
      "organizationName": "Northern Schools Group",
      "role": "owner"
    }
  ],
  "memberships": []
}
```

A person with an organization membership and zero schools is a valid signed-in user. The app opens Account Home so the person can create the first school.

## Create school

`POST /api/v1/organizations/{organizationId}/schools/`

Request:

```json
{
  "name": "Al-Madinah Academy",
  "schoolType": "nursery_primary_secondary",
  "location": "Kaduna, Kaduna State"
}
```

Supported `schoolType` values:

- `nursery`
- `primary`
- `secondary`
- `nursery_primary`
- `primary_secondary`
- `nursery_primary_secondary`
- `college`
- `other`

Successful response:

```json
{
  "membership": {
    "id": "membership-1",
    "schoolId": "school-1",
    "schoolName": "Al-Madinah Academy",
    "role": "proprietor",
    "organizationId": "org-1"
  }
}
```

The app refreshes `/me/` before it will open the newly created school. Returning a membership in the create response is therefore not treated as authorization by itself.

## Required server transaction

School creation must be one server-side transaction. It must either create all of the following or create none of them:

1. school tenant;
2. organization-to-school relationship;
3. creator's proprietor school membership;
4. initial tenant configuration/defaults;
5. audit event recording who created the school.

The client must never create a tenant locally while offline.

## Authorization invariants

- Organization ownership and school operational roles are separate concepts.
- Only authorized organization roles may create schools.
- A person cannot create a school under an organization they do not belong to.
- A newly created school receives its own tenant id and cannot share tenant-scoped records with sibling schools.
- `/me/` remains the canonical list of school memberships the current session may select.
- `SchoolSessionController` continues rejecting a switch to a membership outside that canonical list.

## Current native-app behavior

- Profiles without `organizations` continue using the existing school-selection behavior.
- Profiles with at least one organization open the new Account Home.
- Account Home groups schools by `organizationId`.
- During migration, if exactly one organization exists and old proprietor memberships omit `organizationId`, only proprietor memberships are temporarily associated with that organization. Other roles remain under "Other school access".
- School creation is available only with a configured backend.
- After creation, `/me/` is refreshed before the school workspace opens.

## Next account-layer work

1. implement these organization/profile/provisioning endpoints in the SchoolOS backend;
2. add a persistent "My schools" path from the proprietor workspace back to Account Home;
3. add organization creation/onboarding for a brand-new customer account;
4. add organization administrators and invitations;
5. add subscription, entitlements and billing after multi-school ownership is stable.
