SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict arWNnAFzJH7mFyoZWGeGUwGZCpExMSOI4U3de0p8ROfqQpMHCPtSPfip6tEa57P

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'authenticated', 'authenticated', 'diones.ferreira@gmail.com', NULL, '2026-07-26 17:55:55.27468+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-07-27 18:39:42.917288+00', '{"provider": "google", "providers": ["google"]}', '{"iss": "https://accounts.google.com", "sub": "111172830565099657439", "name": "Diones", "email": "diones.ferreira@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocK3a7QwfoM04UYNOofmQKIu2gqSFcN3_JtGsPZLixzAbFxRTUKdSA=s96-c", "full_name": "Diones", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocK3a7QwfoM04UYNOofmQKIu2gqSFcN3_JtGsPZLixzAbFxRTUKdSA=s96-c", "provider_id": "111172830565099657439", "email_verified": true, "phone_verified": false}', NULL, '2026-07-26 17:55:55.246808+00', '2026-07-28 20:48:56.175005+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', 'authenticated', 'authenticated', 'debi.galmeida@gmail.com', NULL, '2026-07-28 17:24:27.003895+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-07-28 17:24:27.010021+00', '{"provider": "google", "providers": ["google"]}', '{"iss": "https://accounts.google.com", "sub": "102818276358186775842", "name": "Débora Gonçalves de Oliveira", "email": "debi.galmeida@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocJiqO3xpdNup4IKLEWCE56_s8w2lV-6q_okDBPXieJ99C3hDQ=s96-c", "full_name": "Débora Gonçalves de Oliveira", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocJiqO3xpdNup4IKLEWCE56_s8w2lV-6q_okDBPXieJ99C3hDQ=s96-c", "provider_id": "102818276358186775842", "email_verified": true, "phone_verified": false}', NULL, '2026-07-28 17:24:26.966634+00', '2026-07-28 17:24:27.034669+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('111172830565099657439', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '{"iss": "https://accounts.google.com", "sub": "111172830565099657439", "name": "Diones", "email": "diones.ferreira@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocK3a7QwfoM04UYNOofmQKIu2gqSFcN3_JtGsPZLixzAbFxRTUKdSA=s96-c", "full_name": "Diones", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocK3a7QwfoM04UYNOofmQKIu2gqSFcN3_JtGsPZLixzAbFxRTUKdSA=s96-c", "provider_id": "111172830565099657439", "email_verified": true, "phone_verified": false}', 'google', '2026-07-26 17:55:55.266211+00', '2026-07-26 17:55:55.266251+00', '2026-07-27 18:39:42.912343+00', 'a256c552-b1c9-4add-90c8-18f6496f6630'),
	('102818276358186775842', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '{"iss": "https://accounts.google.com", "sub": "102818276358186775842", "name": "Débora Gonçalves de Oliveira", "email": "debi.galmeida@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocJiqO3xpdNup4IKLEWCE56_s8w2lV-6q_okDBPXieJ99C3hDQ=s96-c", "full_name": "Débora Gonçalves de Oliveira", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocJiqO3xpdNup4IKLEWCE56_s8w2lV-6q_okDBPXieJ99C3hDQ=s96-c", "provider_id": "102818276358186775842", "email_verified": true, "phone_verified": false}', 'google', '2026-07-28 17:24:26.991921+00', '2026-07-28 17:24:26.991986+00', '2026-07-28 17:24:26.991986+00', '45ff6df1-a94d-464b-89ee-9bfbca12a5aa');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag", "oauth_client_id", "refresh_token_hmac_key", "refresh_token_counter", "scopes") VALUES
	('e5dc04fc-6326-4783-8fa9-15bea5f1c1ad', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2026-07-27 01:09:42.550331+00', '2026-07-27 18:05:15.327657+00', NULL, 'aal1', NULL, '2026-07-27 18:05:15.32753', 'Mozilla/5.0 (Linux; Android 14; SM-M236B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/150.0.7871.124 Mobile Safari/537.36', '146.70.248.6', NULL, NULL, NULL, NULL, NULL),
	('23b81562-fb1e-4656-9d6c-aa28ca89dc80', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2026-07-27 18:21:20.466373+00', '2026-07-27 18:21:20.466373+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Linux; Android 14; SM-M236B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/150.0.7871.124 Mobile Safari/537.36', '138.199.58.36', NULL, NULL, NULL, NULL, NULL),
	('871de584-b5dc-4ad7-b00b-084c20da62bc', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2026-07-27 18:33:48.15139+00', '2026-07-27 18:33:48.15139+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Linux; Android 14; SM-M236B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/150.0.7871.124 Mobile Safari/537.36', '149.102.251.167', NULL, NULL, NULL, NULL, NULL),
	('65702b71-2b0b-4248-a89e-8640f7af7c7a', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '2026-07-28 17:24:27.011232+00', '2026-07-28 17:24:27.011232+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Linux; Android 14; SM-A725M Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/150.0.7871.181 Mobile Safari/537.36', '201.32.255.82', NULL, NULL, NULL, NULL, NULL),
	('1f870aab-f280-4eea-bb7b-97462014297a', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2026-07-27 18:39:42.918781+00', '2026-07-28 20:48:56.189157+00', NULL, 'aal1', NULL, '2026-07-28 20:48:56.18906', 'Mozilla/5.0 (Linux; Android 14; SM-M236B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/150.0.7871.124 Mobile Safari/537.36', '194.169.171.51', NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('e5dc04fc-6326-4783-8fa9-15bea5f1c1ad', '2026-07-27 01:09:42.555414+00', '2026-07-27 01:09:42.555414+00', 'oauth', '13a7e7c0-0ecc-475f-b339-6b5cedfb84a9'),
	('23b81562-fb1e-4656-9d6c-aa28ca89dc80', '2026-07-27 18:21:20.479234+00', '2026-07-27 18:21:20.479234+00', 'oauth', 'd392fae4-4f52-413b-a05d-7371705427d2'),
	('871de584-b5dc-4ad7-b00b-084c20da62bc', '2026-07-27 18:33:48.162995+00', '2026-07-27 18:33:48.162995+00', 'oauth', '536b5a55-317c-484e-bfb8-b7f526dc06af'),
	('1f870aab-f280-4eea-bb7b-97462014297a', '2026-07-27 18:39:42.9245+00', '2026-07-27 18:39:42.9245+00', 'oauth', 'a5e7af8d-d440-447a-92a2-2a1bdd3831fe'),
	('65702b71-2b0b-4248-a89e-8640f7af7c7a', '2026-07-28 17:24:27.035385+00', '2026-07-28 17:24:27.035385+00', 'oauth', 'e4855203-10a4-4e9d-aff3-2a51cb419674');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") VALUES
	('00000000-0000-0000-0000-000000000000', 7, 'usqwgo3x2rnh', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 01:09:42.551448+00', '2026-07-27 02:23:16.322891+00', NULL, 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 8, 'xrkvljrtpvbq', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 02:23:16.336214+00', '2026-07-27 14:07:17.443903+00', 'usqwgo3x2rnh', 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 9, 'utjq2vzpy2yp', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 14:07:17.456242+00', '2026-07-27 15:05:35.279705+00', 'xrkvljrtpvbq', 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 10, 'd6zguoxidnst', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 15:05:35.295464+00', '2026-07-27 16:04:05.219651+00', 'utjq2vzpy2yp', 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 11, 'emp5wabtwdjy', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 16:04:05.228444+00', '2026-07-27 17:05:04.496386+00', 'd6zguoxidnst', 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 12, 'edy6cyhhxbrd', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 17:05:04.512064+00', '2026-07-27 18:05:15.304854+00', 'emp5wabtwdjy', 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 13, 'inmeqkfih4cn', '2ba1e49e-4d8b-4c43-a005-697426e97dff', false, '2026-07-27 18:05:15.309998+00', '2026-07-27 18:05:15.309998+00', 'edy6cyhhxbrd', 'e5dc04fc-6326-4783-8fa9-15bea5f1c1ad'),
	('00000000-0000-0000-0000-000000000000', 14, 'c3h2vl5645dc', '2ba1e49e-4d8b-4c43-a005-697426e97dff', false, '2026-07-27 18:21:20.47394+00', '2026-07-27 18:21:20.47394+00', NULL, '23b81562-fb1e-4656-9d6c-aa28ca89dc80'),
	('00000000-0000-0000-0000-000000000000', 15, 'db4q73qmhee6', '2ba1e49e-4d8b-4c43-a005-697426e97dff', false, '2026-07-27 18:33:48.155845+00', '2026-07-27 18:33:48.155845+00', NULL, '871de584-b5dc-4ad7-b00b-084c20da62bc'),
	('00000000-0000-0000-0000-000000000000', 16, 'gqtkmezjbkxo', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 18:39:42.920278+00', '2026-07-27 21:03:45.825901+00', NULL, '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 18, 'vwjc4qvgyy2h', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', false, '2026-07-28 17:24:27.022601+00', '2026-07-28 17:24:27.022601+00', NULL, '65702b71-2b0b-4248-a89e-8640f7af7c7a'),
	('00000000-0000-0000-0000-000000000000', 17, '6rie7uli62w7', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-27 21:03:45.84772+00', '2026-07-28 17:37:35.491715+00', 'gqtkmezjbkxo', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 19, 'b4u7yd3abs5l', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-28 17:37:35.496367+00', '2026-07-28 20:48:56.153672+00', '6rie7uli62w7', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 20, 'x5otax5nchgh', '2ba1e49e-4d8b-4c43-a005-697426e97dff', false, '2026-07-28 20:48:56.169796+00', '2026-07-28 20:48:56.169796+00', 'b4u7yd3abs5l', '1f870aab-f280-4eea-bb7b-97462014297a');


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: ranked_game_sessions; Type: TABLE DATA; Schema: private; Owner: postgres
--

INSERT INTO "private"."ranked_game_sessions" ("id", "user_id", "session_nonce_hash", "mode", "variation", "status", "expires_at", "created_at") VALUES
	('8ac589a3-3f3d-4b50-9328-4bbb18f065de', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'bd6b8ee457973dab39420ca0dc248963360e07f3bbdf284e1e4646768015749d', 'world', '10', 'created', '2026-07-27 18:16:47.455977+00', '2026-07-27 17:46:47.455977+00'),
	('8a3292f8-80a1-4558-915b-1c95585c2640', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '300800091ba1e6c1893a0897a398314d66257d64ed8e05ab31eaa5497137e510', 'world', '10', 'created', '2026-07-27 18:18:31.001931+00', '2026-07-27 17:48:31.001931+00'),
	('b95d8efa-61bd-4403-8d3f-c99f4168da3b', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '87d0703580f53a98b2fb41f21fa05de2d33d58062883bbc5a98f350b221e9156', 'world', '10', 'created', '2026-07-27 18:19:18.187267+00', '2026-07-27 17:49:18.187267+00'),
	('1d6c1eba-540d-47bf-905f-89472f400bc5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '29350ea3caa0afaef0a99ea86d613131c9cb06a68cc1bdfd5a84ec6a84ed3881', 'world', '10', 'created', '2026-07-27 18:21:13.79654+00', '2026-07-27 17:51:13.79654+00'),
	('d4f2b7fe-0c5e-4b46-b7b4-b6a97769e370', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '39cd155943e7479924467b4a31cd656b357d964bed46718b2a6bd0e0c614bf90', 'world', '10', 'created', '2026-07-27 18:21:44.176706+00', '2026-07-27 17:51:44.176706+00'),
	('92b294e5-0314-4dda-b3f1-9c40477b9dba', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '80107b151a37e1d5c5a48c78bcbcc2ac4100be4a97935e03c50744bef12524ca', 'world', '10', 'created', '2026-07-27 18:33:13.584659+00', '2026-07-27 18:03:13.584659+00'),
	('b5fb436c-ff59-4899-9dbd-986b687c51d5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'f781d7acff12d1e8ea763ddbf15e42432215f843aefac8118d0bf2b11670a4f2', 'world', '10', 'created', '2026-07-27 18:34:57.159+00', '2026-07-27 18:04:57.159+00'),
	('ce30ba81-0f1c-4eab-9c4b-52381130a90e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'ec0160dd4f20b6a2c68eb5f87e3a0785966b771d7cecc24cd29c6115aa3f053b', 'world', '10', 'created', '2026-07-27 18:35:22.239432+00', '2026-07-27 18:05:22.239432+00'),
	('5a9a4403-8cd5-4f46-bfac-29c77bcc1a25', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '0d39addb075769f701526a9cbf3e9f1bfd69670721b7cc8993cee5d01989c2b4', 'world', '10', 'created', '2026-07-27 18:36:26.360197+00', '2026-07-27 18:06:26.360197+00'),
	('2c5f943b-7844-4c42-895b-abbb8ea914a5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'f87c2384204c95ece9f3e2c78a83b196c80e60a48ed9147fd5e0e1e818887657', 'world', '10', 'created', '2026-07-27 18:40:21.500139+00', '2026-07-27 18:10:21.500139+00'),
	('40d60ba5-be6a-4254-8c3a-4906a7700c8e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '246654b7a6708c97639e309d14faf87e22af55e1e98bdcca06cae8eaa5317fbe', 'world', '10', 'created', '2026-07-27 18:51:36.944209+00', '2026-07-27 18:21:36.944209+00'),
	('162275be-bf98-4c30-9b72-7bc16886cdbd', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '1502d0902b4b70d4c857c7f37569fceddf06ef7a972db3fe29fd56877f261508', 'world', '10', 'created', '2026-07-27 18:55:38.994798+00', '2026-07-27 18:25:38.994798+00'),
	('7d0c5109-d028-4d81-9d8d-8b862c1b3806', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '718bfc1a3e49052ca29137f03f02463eff123b4cdb63485f39d87dac1d94fdd5', 'world', '10', 'created', '2026-07-27 19:02:01.244535+00', '2026-07-27 18:32:01.244535+00'),
	('2460759c-330c-4191-9df5-e64e50a275d3', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'e478c07fa5d49d4dd442df75de99341589acba1341bdb546a1c985383f58c84f', 'world', '10', 'created', '2026-07-27 19:04:09.730308+00', '2026-07-27 18:34:09.730308+00'),
	('7006b732-24b7-4dc7-bc64-869881906dab', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'd69fb8b3e59d776a7822d9bd79710613a8e35a15188571a889928e0fbdcde2ea', 'world', '10', 'created', '2026-07-27 19:07:32.728232+00', '2026-07-27 18:37:32.728232+00'),
	('69f702d7-c821-4010-8022-d4af5f67efc3', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'fafca2cd3e5247238cf90862640723cd13153d43dfc1b1ea622a6fc7c2193d53', 'world', '10', 'created', '2026-07-27 19:09:56.225994+00', '2026-07-27 18:39:56.225994+00'),
	('061fdb5f-9ed1-45d9-89f2-a33baa09335e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '6c0806701065e2131e292afe8eb3e78b5387ab6196609cb1649d65d1fa917512', 'world', '10', 'created', '2026-07-27 19:20:11.93034+00', '2026-07-27 18:50:11.93034+00'),
	('243fcb00-3ce3-41fe-a1df-d7e1b241cebd', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '475e82407b7fcff20053ca99d6db6d2af15f1143fe3ec8b0b65b632e3d34d358', 'world', '10', 'created', '2026-07-27 19:23:17.028905+00', '2026-07-27 18:53:17.028905+00'),
	('f196294c-ec64-4841-ba26-e222ba4935da', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'eeaa8d229f377386551e5e804119d571088d58762b60a09803a52f0caee2af0b', 'world', '10', 'created', '2026-07-27 19:30:46.600267+00', '2026-07-27 19:00:46.600267+00'),
	('300eaa10-1cb2-4d67-982d-ad84768bb56d', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '30baf5a74e35851128e40f44d6402b0e1436d0dd44512c99bfc6b04081001d52', 'world', '10', 'completed', '2026-07-27 19:34:08.903755+00', '2026-07-27 19:04:08.903755+00'),
	('244addf8-bb5e-4243-bfa7-1a50c34e74fe', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2dd5f61a35f226ed7821d3e9d2bb849961c73523add83b6395bb5a88d051d12b', 'world', '10', 'completed', '2026-07-27 19:38:41.855976+00', '2026-07-27 19:08:41.855976+00'),
	('ff7deef4-c5e5-44f2-baef-e026b506a791', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'bca2dc62eec618d5f4a575c8d0a8673f595a6794784f88a9f44d9283d2b0ffc3', 'world', '50', 'created', '2026-07-27 19:48:02.5541+00', '2026-07-27 19:18:02.5541+00'),
	('1b659d3a-3536-4382-b36f-075359914352', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '5f286f6841ed7ead4f97ca8536209931c9a32b4f7b8903c3b85b95e603a8846f', 'world', '10', 'created', '2026-07-28 17:54:44.382759+00', '2026-07-28 17:24:44.382759+00'),
	('1ec683d6-10bc-4488-98cf-1a1fec73be5e', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '391390ae1d7b7b7a0dd5a1ab5498a8f821f5c4ff53cec8dd2f3c464cc55dc599', 'world', '10', 'completed', '2026-07-28 17:55:57.118465+00', '2026-07-28 17:25:57.118465+00'),
	('fcce26ad-6ed8-4d80-995e-589a703f4924', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', 'eab6c3dee6d509ea2d02edd750ba9ef6552b195084b83dcd02eec3dc216442a2', 'world', '10', 'completed', '2026-07-28 17:57:34.518153+00', '2026-07-28 17:27:34.518153+00'),
	('da91b568-d423-4277-b7dc-19d83d4e4262', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'ba00052a6282f44fc4808e26b47d5c9ca517587152bae88d9a89bd573b1df4d9', 'world', '10', 'completed', '2026-07-28 18:08:31.108394+00', '2026-07-28 17:38:31.108394+00'),
	('467c56b8-7e70-498f-918b-ee8e091c4ef8', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'da71dec9eb21fe88199c2b94d671e85725fd8b463284dcb9ad6434c0e87eb67d', 'world', '10', 'completed', '2026-07-28 21:20:51.544281+00', '2026-07-28 20:50:51.544281+00');


--
-- Data for Name: challenges; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: game_results; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."game_results" ("id", "event_id", "user_id", "ranked_session_id", "score", "correct_answers", "total_questions", "accuracy", "elapsed_time_ms", "hearts_used", "is_ranked", "verification_status", "received_at") VALUES
	('a9dbf5b4-49c3-48db-96f7-a6c56dfe6c56', 'fg_event_ms3ljazk_wz15k1yl13m6', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '300eaa10-1cb2-4d67-982d-ad84768bb56d', 2, 2, 10, 20.00, 38000, false, true, 'verified', '2026-07-27 19:04:47.265715+00'),
	('89d9bb76-3b6f-4286-a8c9-fefa115ca25d', 'fg_event_ms3lp66l_bxf1xca8ypta', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '244addf8-bb5e-4243-bfa7-1a50c34e74fe', 3, 3, 10, 30.00, 38000, false, true, 'verified', '2026-07-27 19:09:21.040753+00'),
	('4852201b-2ecb-4eac-b875-5cff7197ada2', 'fg_event_ms4xgvlx_13t6rl1etqu9c', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '1ec683d6-10bc-4488-98cf-1a1fec73be5e', 8, 8, 10, 80.00, 37000, false, true, 'verified', '2026-07-28 17:26:35.299114+00'),
	('f7046750-8326-4e53-82af-42581d46165f', 'fg_event_ms4xj8lx_v5zffw1jnt1v8', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', 'fcce26ad-6ed8-4d80-995e-589a703f4924', 9, 9, 10, 90.00, 50000, false, true, 'verified', '2026-07-28 17:28:25.387575+00'),
	('0a041c4b-1bd7-4f84-82bd-87300f22f754', 'fg_event_ms4xx87j_bne5ak1gisc50', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'da91b568-d423-4277-b7dc-19d83d4e4262', 9, 9, 10, 90.00, 47000, false, true, 'verified', '2026-07-28 17:39:18.604233+00'),
	('69745df9-40c4-4c5b-8fe9-1bef7d22e770', 'fg_event_ms54rkwm_1wbwkzk1riwubv', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '467c56b8-7e70-498f-918b-ee8e091c4ef8', 9, 9, 10, 90.00, 70000, false, true, 'verified', '2026-07-28 20:52:03.221187+00');


--
-- Data for Name: challenge_base_match_sessions; Type: TABLE DATA; Schema: private; Owner: postgres
--



--
-- Data for Name: challenge_configs; Type: TABLE DATA; Schema: private; Owner: postgres
--



--
-- Data for Name: challenge_participants; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: challenge_sessions; Type: TABLE DATA; Schema: private; Owner: postgres
--



--
-- Data for Name: supporter_entitlements; Type: TABLE DATA; Schema: private; Owner: postgres
--



--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."profiles" ("id", "nickname", "country_code", "avatar_key", "privacy_settings", "created_at", "updated_at") VALUES
	('5eddae10-9ca3-4df1-aa45-f1d1377383fe', 'Debora Goncalves de Oliv', NULL, NULL, '{"show_detailed_stats": false}', '2026-07-28 17:24:28.260233+00', '2026-07-28 17:24:28.260233+00'),
	('2ba1e49e-4d8b-4c43-a005-697426e97dff', 'Diones Almeida', NULL, NULL, '{"show_wrong_flags": false, "show_detailed_stats": true, "show_recent_activity": false, "show_challenge_history": true}', '2026-07-26 19:29:47.002855+00', '2026-07-26 19:29:47.002855+00');


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 20, true);


--
-- PostgreSQL database dump complete
--

-- \unrestrict arWNnAFzJH7mFyoZWGeGUwGZCpExMSOI4U3de0p8ROfqQpMHCPtSPfip6tEa57P

RESET ALL;
