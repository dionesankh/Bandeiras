SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict b2h5ieCYledjzkxAy8rbx20rs94gqoOvLwaUaCuLkKoNQLFZ7hpQG2UG5dwjSSv

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
	('00000000-0000-0000-0000-000000000000', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'authenticated', 'authenticated', 'diones.ferreira@gmail.com', NULL, '2026-07-26 17:55:55.27468+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-07-27 18:39:42.917288+00', '{"provider": "google", "providers": ["google"]}', '{"iss": "https://accounts.google.com", "sub": "111172830565099657439", "name": "Diones", "email": "diones.ferreira@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocK3a7QwfoM04UYNOofmQKIu2gqSFcN3_JtGsPZLixzAbFxRTUKdSA=s96-c", "full_name": "Diones", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocK3a7QwfoM04UYNOofmQKIu2gqSFcN3_JtGsPZLixzAbFxRTUKdSA=s96-c", "provider_id": "111172830565099657439", "email_verified": true, "phone_verified": false}', NULL, '2026-07-26 17:55:55.246808+00', '2026-07-30 18:49:13.266665+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
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
	('1f870aab-f280-4eea-bb7b-97462014297a', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2026-07-27 18:39:42.918781+00', '2026-07-30 18:49:13.282612+00', NULL, 'aal1', NULL, '2026-07-30 18:49:13.282486', 'Mozilla/5.0 (Linux; Android 14; SM-M236B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/150.0.7871.181 Mobile Safari/537.36', '194.26.131.19', NULL, NULL, NULL, NULL, NULL);


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
	('00000000-0000-0000-0000-000000000000', 20, 'x5otax5nchgh', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-28 20:48:56.169796+00', '2026-07-30 01:05:26.225932+00', 'b4u7yd3abs5l', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 21, 'rzyuvqbx33a5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-30 01:05:26.248746+00', '2026-07-30 15:15:59.432699+00', 'x5otax5nchgh', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 22, 'fycrvdg26eaw', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-30 15:15:59.451431+00', '2026-07-30 16:14:21.274429+00', 'rzyuvqbx33a5', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 23, 'tmkglbkpporz', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-30 16:14:21.281652+00', '2026-07-30 17:12:51.052772+00', 'fycrvdg26eaw', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 24, 'wb45eslf6yvz', '2ba1e49e-4d8b-4c43-a005-697426e97dff', true, '2026-07-30 17:12:51.06262+00', '2026-07-30 18:49:13.252603+00', 'tmkglbkpporz', '1f870aab-f280-4eea-bb7b-97462014297a'),
	('00000000-0000-0000-0000-000000000000', 25, 'na3rt3cft66c', '2ba1e49e-4d8b-4c43-a005-697426e97dff', false, '2026-07-30 18:49:13.261236+00', '2026-07-30 18:49:13.261236+00', 'wb45eslf6yvz', '1f870aab-f280-4eea-bb7b-97462014297a');


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
-- Data for Name: challenges; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."challenges" ("id", "creator_id", "code", "mode", "variation", "idempotency_key", "status", "expires_at", "created_at", "config", "rules_version", "allow_hearts", "cancelled_at") VALUES
	('bb3760de-4f52-4ea1-b38d-e60c432fb235', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'FG-UL66JUED', 'world', '10', 'fg_event_ms6u7y7h_1m0jxo3dlwy2o', 'open', NULL, '2026-07-30 01:31:36.224607+00', '{"mode": "world", "source": "completed_match", "variation": "10", "allow_hearts": false, "rules_version": 1, "sequence_hash": "484696fa1c04d7ffd1adc06b6e59107213683f59bd5d128f923f866bc97236d8", "question_count": 10}', 1, false, NULL);


--
-- Data for Name: ranked_game_sessions; Type: TABLE DATA; Schema: private; Owner: postgres
--

INSERT INTO "private"."ranked_game_sessions" ("id", "user_id", "session_nonce_hash", "mode", "variation", "status", "expires_at", "created_at", "seed", "algorithm_version", "question_codes", "question_count", "sequence_hash", "challenge_id", "promotion_idempotency_key", "rules_version", "allow_hearts", "started_at", "completed_at", "result_id") VALUES
	('8ac589a3-3f3d-4b50-9328-4bbb18f065de', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'bd6b8ee457973dab39420ca0dc248963360e07f3bbdf284e1e4646768015749d', 'world', '10', 'created', '2026-07-27 18:16:47.455977+00', '2026-07-27 17:46:47.455977+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 17:46:47.455977+00', NULL, NULL),
	('8a3292f8-80a1-4558-915b-1c95585c2640', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '300800091ba1e6c1893a0897a398314d66257d64ed8e05ab31eaa5497137e510', 'world', '10', 'created', '2026-07-27 18:18:31.001931+00', '2026-07-27 17:48:31.001931+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 17:48:31.001931+00', NULL, NULL),
	('b95d8efa-61bd-4403-8d3f-c99f4168da3b', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '87d0703580f53a98b2fb41f21fa05de2d33d58062883bbc5a98f350b221e9156', 'world', '10', 'created', '2026-07-27 18:19:18.187267+00', '2026-07-27 17:49:18.187267+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 17:49:18.187267+00', NULL, NULL),
	('1d6c1eba-540d-47bf-905f-89472f400bc5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '29350ea3caa0afaef0a99ea86d613131c9cb06a68cc1bdfd5a84ec6a84ed3881', 'world', '10', 'created', '2026-07-27 18:21:13.79654+00', '2026-07-27 17:51:13.79654+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 17:51:13.79654+00', NULL, NULL),
	('d4f2b7fe-0c5e-4b46-b7b4-b6a97769e370', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '39cd155943e7479924467b4a31cd656b357d964bed46718b2a6bd0e0c614bf90', 'world', '10', 'created', '2026-07-27 18:21:44.176706+00', '2026-07-27 17:51:44.176706+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 17:51:44.176706+00', NULL, NULL),
	('92b294e5-0314-4dda-b3f1-9c40477b9dba', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '80107b151a37e1d5c5a48c78bcbcc2ac4100be4a97935e03c50744bef12524ca', 'world', '10', 'created', '2026-07-27 18:33:13.584659+00', '2026-07-27 18:03:13.584659+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:03:13.584659+00', NULL, NULL),
	('b5fb436c-ff59-4899-9dbd-986b687c51d5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'f781d7acff12d1e8ea763ddbf15e42432215f843aefac8118d0bf2b11670a4f2', 'world', '10', 'created', '2026-07-27 18:34:57.159+00', '2026-07-27 18:04:57.159+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:04:57.159+00', NULL, NULL),
	('ce30ba81-0f1c-4eab-9c4b-52381130a90e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'ec0160dd4f20b6a2c68eb5f87e3a0785966b771d7cecc24cd29c6115aa3f053b', 'world', '10', 'created', '2026-07-27 18:35:22.239432+00', '2026-07-27 18:05:22.239432+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:05:22.239432+00', NULL, NULL),
	('5a9a4403-8cd5-4f46-bfac-29c77bcc1a25', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '0d39addb075769f701526a9cbf3e9f1bfd69670721b7cc8993cee5d01989c2b4', 'world', '10', 'created', '2026-07-27 18:36:26.360197+00', '2026-07-27 18:06:26.360197+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:06:26.360197+00', NULL, NULL),
	('2c5f943b-7844-4c42-895b-abbb8ea914a5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'f87c2384204c95ece9f3e2c78a83b196c80e60a48ed9147fd5e0e1e818887657', 'world', '10', 'created', '2026-07-27 18:40:21.500139+00', '2026-07-27 18:10:21.500139+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:10:21.500139+00', NULL, NULL),
	('40d60ba5-be6a-4254-8c3a-4906a7700c8e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '246654b7a6708c97639e309d14faf87e22af55e1e98bdcca06cae8eaa5317fbe', 'world', '10', 'created', '2026-07-27 18:51:36.944209+00', '2026-07-27 18:21:36.944209+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:21:36.944209+00', NULL, NULL),
	('162275be-bf98-4c30-9b72-7bc16886cdbd', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '1502d0902b4b70d4c857c7f37569fceddf06ef7a972db3fe29fd56877f261508', 'world', '10', 'created', '2026-07-27 18:55:38.994798+00', '2026-07-27 18:25:38.994798+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:25:38.994798+00', NULL, NULL),
	('7d0c5109-d028-4d81-9d8d-8b862c1b3806', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '718bfc1a3e49052ca29137f03f02463eff123b4cdb63485f39d87dac1d94fdd5', 'world', '10', 'created', '2026-07-27 19:02:01.244535+00', '2026-07-27 18:32:01.244535+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:32:01.244535+00', NULL, NULL),
	('2460759c-330c-4191-9df5-e64e50a275d3', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'e478c07fa5d49d4dd442df75de99341589acba1341bdb546a1c985383f58c84f', 'world', '10', 'created', '2026-07-27 19:04:09.730308+00', '2026-07-27 18:34:09.730308+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:34:09.730308+00', NULL, NULL),
	('7006b732-24b7-4dc7-bc64-869881906dab', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'd69fb8b3e59d776a7822d9bd79710613a8e35a15188571a889928e0fbdcde2ea', 'world', '10', 'created', '2026-07-27 19:07:32.728232+00', '2026-07-27 18:37:32.728232+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:37:32.728232+00', NULL, NULL),
	('69f702d7-c821-4010-8022-d4af5f67efc3', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'fafca2cd3e5247238cf90862640723cd13153d43dfc1b1ea622a6fc7c2193d53', 'world', '10', 'created', '2026-07-27 19:09:56.225994+00', '2026-07-27 18:39:56.225994+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:39:56.225994+00', NULL, NULL),
	('061fdb5f-9ed1-45d9-89f2-a33baa09335e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '6c0806701065e2131e292afe8eb3e78b5387ab6196609cb1649d65d1fa917512', 'world', '10', 'created', '2026-07-27 19:20:11.93034+00', '2026-07-27 18:50:11.93034+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:50:11.93034+00', NULL, NULL),
	('243fcb00-3ce3-41fe-a1df-d7e1b241cebd', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '475e82407b7fcff20053ca99d6db6d2af15f1143fe3ec8b0b65b632e3d34d358', 'world', '10', 'created', '2026-07-27 19:23:17.028905+00', '2026-07-27 18:53:17.028905+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 18:53:17.028905+00', NULL, NULL),
	('b47104e9-0668-45a4-b57a-22a216fa49aa', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '7bf712dc9381aeb4bbeb3e9547f21b7d5555344c6ff2b13d2b22cad388f35c7d', 'world', '10', 'completed', '2026-07-30 15:46:06.989671+00', '2026-07-30 15:16:06.989671+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 15:16:06.989671+00', NULL, NULL),
	('f196294c-ec64-4841-ba26-e222ba4935da', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'eeaa8d229f377386551e5e804119d571088d58762b60a09803a52f0caee2af0b', 'world', '10', 'created', '2026-07-27 19:30:46.600267+00', '2026-07-27 19:00:46.600267+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 19:00:46.600267+00', NULL, NULL),
	('300eaa10-1cb2-4d67-982d-ad84768bb56d', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '30baf5a74e35851128e40f44d6402b0e1436d0dd44512c99bfc6b04081001d52', 'world', '10', 'completed', '2026-07-27 19:34:08.903755+00', '2026-07-27 19:04:08.903755+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 19:04:08.903755+00', NULL, NULL),
	('244addf8-bb5e-4243-bfa7-1a50c34e74fe', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2dd5f61a35f226ed7821d3e9d2bb849961c73523add83b6395bb5a88d051d12b', 'world', '10', 'completed', '2026-07-27 19:38:41.855976+00', '2026-07-27 19:08:41.855976+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 19:08:41.855976+00', NULL, NULL),
	('ff7deef4-c5e5-44f2-baef-e026b506a791', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'bca2dc62eec618d5f4a575c8d0a8673f595a6794784f88a9f44d9283d2b0ffc3', 'world', '50', 'created', '2026-07-27 19:48:02.5541+00', '2026-07-27 19:18:02.5541+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-27 19:18:02.5541+00', NULL, NULL),
	('1b659d3a-3536-4382-b36f-075359914352', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '5f286f6841ed7ead4f97ca8536209931c9a32b4f7b8903c3b85b95e603a8846f', 'world', '10', 'created', '2026-07-28 17:54:44.382759+00', '2026-07-28 17:24:44.382759+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-28 17:24:44.382759+00', NULL, NULL),
	('1ec683d6-10bc-4488-98cf-1a1fec73be5e', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '391390ae1d7b7b7a0dd5a1ab5498a8f821f5c4ff53cec8dd2f3c464cc55dc599', 'world', '10', 'completed', '2026-07-28 17:55:57.118465+00', '2026-07-28 17:25:57.118465+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-28 17:25:57.118465+00', NULL, NULL),
	('fcce26ad-6ed8-4d80-995e-589a703f4924', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', 'eab6c3dee6d509ea2d02edd750ba9ef6552b195084b83dcd02eec3dc216442a2', 'world', '10', 'completed', '2026-07-28 17:57:34.518153+00', '2026-07-28 17:27:34.518153+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-28 17:27:34.518153+00', NULL, NULL),
	('da91b568-d423-4277-b7dc-19d83d4e4262', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'ba00052a6282f44fc4808e26b47d5c9ca517587152bae88d9a89bd573b1df4d9', 'world', '10', 'completed', '2026-07-28 18:08:31.108394+00', '2026-07-28 17:38:31.108394+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-28 17:38:31.108394+00', NULL, NULL),
	('467c56b8-7e70-498f-918b-ee8e091c4ef8', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'da71dec9eb21fe88199c2b94d671e85725fd8b463284dcb9ad6434c0e87eb67d', 'world', '10', 'completed', '2026-07-28 21:20:51.544281+00', '2026-07-28 20:50:51.544281+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-28 20:50:51.544281+00', NULL, NULL),
	('02697e54-7c9d-425c-8ef9-56d91d0354f8', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'ff5f1cb7e1ff77315035e7fba8bd8012b417f0b33d377e116760090b9b6b7014', 'world', '10', 'completed', '2026-07-30 01:36:14.094613+00', '2026-07-30 01:06:14.094613+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 01:06:14.094613+00', NULL, NULL),
	('d7d5e47d-365c-4189-a6ce-a7565ca3220f', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'e88c98880a4ee5289be40a1f9802113ec05ce51b849763bc2da69d21e030501d', 'world', '10', 'completed', '2026-07-30 01:55:39.030417+00', '2026-07-30 01:25:39.030417+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 01:25:39.030417+00', NULL, NULL),
	('89a1aee9-5996-4b4d-af0a-6b559a7eae8e', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '44b50415fecc13156a2ec65e12051f1528c8e038ba401876d26d87bf75605a94', 'world', '10', 'completed', '2026-07-30 02:00:32.171689+00', '2026-07-30 01:30:32.171689+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 01:30:32.171689+00', NULL, NULL),
	('79be075f-d829-4e3f-961a-389a5f5790d2', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '17becc72bab9a2ad00049e9e9dfdb97ad93ee082bb67f2c24e7d87c011922d68', 'world', '10', 'completed', '2026-07-30 02:04:43.990474+00', '2026-07-30 01:34:43.990474+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 01:34:43.990474+00', NULL, NULL),
	('c89d73c7-aa69-4a4c-9b38-8a419a8badd9', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '91179ddb6ae34f33e2bb6b59c1dda48c21f98d5c0f89a819dbb5900c269381e6', 'world', '10', 'completed', '2026-07-30 02:06:06.773248+00', '2026-07-30 01:36:06.773248+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 01:36:06.773248+00', NULL, NULL),
	('c442dc3e-66b2-4660-9b7b-0ae0ee279664', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '6191953b36366f3e58d527c420286b23d5bf400cb8537128a8957e8e90296671', 'world', '10', 'completed', '2026-07-30 02:21:21.375536+00', '2026-07-30 01:51:21.375536+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 01:51:21.375536+00', NULL, NULL),
	('d77a1cf1-4082-4468-93cb-d43e6fe5e9ef', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'e62ad1c1f35664014e73e7c6c4a2bd9e9fce04f683161f45d584fb719f49f0da', 'world', '10', 'completed', '2026-07-30 16:33:35.471575+00', '2026-07-30 16:03:35.471575+00', NULL, 'server-sequence-v1', NULL, NULL, NULL, NULL, NULL, 1, false, '2026-07-30 16:03:35.471575+00', NULL, NULL),
	('03001702-37f3-4d31-b34a-d04ceaca5bca', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '2405d8f9ae97f3a9fa5e031f4315364a49dd39c1ad4abc4569eb40b3a849d7df', 'world', '10', 'completed', '2026-07-30 18:09:15.81716+00', '2026-07-30 17:39:15.81716+00', '624d3b5136cf0611d11f9871f8b5437a', 'server-sequence-v1', '["ML", "FI", "LA", "SV", "IS", "LT", "AO", "DM", "MN", "MG"]', 10, '1baaa8582d1977c71278bb1fcbf2c2e1844bb9b57d21f2e641793ab6fe10c5a1', NULL, NULL, 1, false, '2026-07-30 17:39:15.81716+00', '2026-07-30 17:39:35.79708+00', '6fa11a8f-e0b4-4c4b-94c9-8a54c036bb8e'),
	('429e72d4-df8b-4778-8c8a-1fab029dc305', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '784f61cbbcbb1ca52733e0c7e5f4be856a785d799b0f9f52781f44a99a96a9b2', 'world', '10', 'created', '2026-07-30 19:21:04.744196+00', '2026-07-30 18:51:04.744196+00', '467be63a1a0d0624ff4334eb69da5916', 'server-sequence-v1', '["MD", "PG", "NZ", "BB", "TL", "ZM", "BW", "MU", "SE", "AM"]', 10, '5462c790439a787f53ccc0af4d9b4e08035041d79f80197da45594158f3b582d', NULL, NULL, 1, false, '2026-07-30 18:51:04.744196+00', NULL, NULL),
	('07ddce0c-054c-448c-8d96-15016ac88c47', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'c758baa8fa25af4e2317eed8e0d5482982653d716be5ff56c888a106f86a4949', 'world', '10', 'completed', '2026-07-30 19:29:18.566776+00', '2026-07-30 18:59:18.566776+00', 'f6b956781ec93fd419ab0bf541f98365', 'server-sequence-v1', '["LY", "SK", "KN", "CA", "DZ", "ER", "PH", "MT", "PG", "IL"]', 10, '9a6d851301e9ba3c6a506d41dfd276f4832ec5266580664b73ea05a2dfe3092d', NULL, NULL, 1, false, '2026-07-30 18:59:18.566776+00', '2026-07-30 18:59:39.719577+00', '9802aa46-5ee1-4812-99b9-02054c5f5e45');


--
-- Data for Name: game_results; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."game_results" ("id", "event_id", "user_id", "ranked_session_id", "score", "correct_answers", "total_questions", "accuracy", "elapsed_time_ms", "hearts_used", "is_ranked", "verification_status", "received_at") VALUES
	('a9dbf5b4-49c3-48db-96f7-a6c56dfe6c56', 'fg_event_ms3ljazk_wz15k1yl13m6', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '300eaa10-1cb2-4d67-982d-ad84768bb56d', 2, 2, 10, 20.00, 38000, false, true, 'verified', '2026-07-27 19:04:47.265715+00'),
	('89d9bb76-3b6f-4286-a8c9-fefa115ca25d', 'fg_event_ms3lp66l_bxf1xca8ypta', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '244addf8-bb5e-4243-bfa7-1a50c34e74fe', 3, 3, 10, 30.00, 38000, false, true, 'verified', '2026-07-27 19:09:21.040753+00'),
	('4852201b-2ecb-4eac-b875-5cff7197ada2', 'fg_event_ms4xgvlx_13t6rl1etqu9c', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', '1ec683d6-10bc-4488-98cf-1a1fec73be5e', 8, 8, 10, 80.00, 37000, false, true, 'verified', '2026-07-28 17:26:35.299114+00'),
	('f7046750-8326-4e53-82af-42581d46165f', 'fg_event_ms4xj8lx_v5zffw1jnt1v8', '5eddae10-9ca3-4df1-aa45-f1d1377383fe', 'fcce26ad-6ed8-4d80-995e-589a703f4924', 9, 9, 10, 90.00, 50000, false, true, 'verified', '2026-07-28 17:28:25.387575+00'),
	('0a041c4b-1bd7-4f84-82bd-87300f22f754', 'fg_event_ms4xx87j_bne5ak1gisc50', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'da91b568-d423-4277-b7dc-19d83d4e4262', 9, 9, 10, 90.00, 47000, false, true, 'verified', '2026-07-28 17:39:18.604233+00'),
	('69745df9-40c4-4c5b-8fe9-1bef7d22e770', 'fg_event_ms54rkwm_1wbwkzk1riwubv', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '467c56b8-7e70-498f-918b-ee8e091c4ef8', 9, 9, 10, 90.00, 70000, false, true, 'verified', '2026-07-28 20:52:03.221187+00'),
	('de3a707f-bdcc-445f-8fe9-3a8b2c94c3de', 'fg_event_ms6tbtvm_1tcsqysaldpv5', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '02697e54-7c9d-425c-8ef9-56d91d0354f8', 4, 4, 10, 40.00, 21000, false, true, 'verified', '2026-07-30 01:06:45.032182+00'),
	('38db39a9-24e8-480a-bc9a-8ed4a19283b2', 'fg_event_ms6u0sok_14seibf78dapd', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'd7d5e47d-365c-4189-a6ce-a7565ca3220f', 4, 4, 10, 40.00, 23000, false, true, 'verified', '2026-07-30 01:26:02.985771+00'),
	('43ee92cd-8178-44db-bda5-d9d4fb36f717', 'fg_event_ms6u72t1_p6nhug1dx78v6', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '89a1aee9-5996-4b4d-af0a-6b559a7eae8e', 5, 5, 10, 50.00, 20000, false, true, 'verified', '2026-07-30 01:30:52.979525+00'),
	('3de175b5-722c-4179-8937-bab506ed4021', 'fg_event_ms6u7y7h_1m0jxo3dlwy2o', '2ba1e49e-4d8b-4c43-a005-697426e97dff', NULL, 4, 4, 10, 40.00, 20000, false, false, 'verified', '2026-07-30 01:31:36.224607+00'),
	('60b46bf1-98e5-4933-940e-f34bd6b8f55d', 'fg_event_ms6uch4h_zfohs5hgls2u', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '79be075f-d829-4e3f-961a-389a5f5790d2', 6, 6, 10, 60.00, 22000, false, true, 'verified', '2026-07-30 01:35:07.494317+00'),
	('0ec9f24a-b06a-4cc9-ac4a-6a2b292ea703', 'fg_event_ms6ue8ym_ecb3gm1bxs9yw', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'c89d73c7-aa69-4a4c-9b38-8a419a8badd9', 4, 4, 10, 40.00, 18000, false, true, 'verified', '2026-07-30 01:36:25.402449+00'),
	('21e74ca1-d798-4c1b-be7c-89a59554c533', 'fg_event_ms6uxuoy_1xh3lah1e00b8p', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'c442dc3e-66b2-4660-9b7b-0ae0ee279664', 4, 4, 10, 40.00, 22000, false, true, 'verified', '2026-07-30 01:51:44.462024+00'),
	('d50baa5e-680c-42bd-97d4-47b3b3b1dbd9', 'fg_event_ms7nosol_10vxlnr1yo9gne', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'b47104e9-0668-45a4-b57a-22a216fa49aa', 1, 1, 10, 10.00, 20000, false, true, 'verified', '2026-07-30 15:16:28.129867+00'),
	('7073b0ef-a252-4d6d-8e4d-46e65a0bcca9', 'fg_event_ms7pdukt_tx3r9eu71z6q', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'd77a1cf1-4082-4468-93cb-d43e6fe5e9ef', 0, 0, 10, 0.00, 20000, false, true, 'verified', '2026-07-30 16:03:56.470135+00'),
	('6fa11a8f-e0b4-4c4b-94c9-8a54c036bb8e', 'fg_event_ms7ssvus_c6r5fb1ndkll3', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '03001702-37f3-4d31-b34a-d04ceaca5bca', 2, 2, 10, 20.00, 19000, false, true, 'verified', '2026-07-30 17:39:35.79708+00'),
	('9802aa46-5ee1-4812-99b9-02054c5f5e45', 'fg_event_ms7vntjy_al5du3kx3xrf', '2ba1e49e-4d8b-4c43-a005-697426e97dff', '07ddce0c-054c-448c-8d96-15016ac88c47', 1, 1, 10, 10.00, 20000, false, true, 'verified', '2026-07-30 18:59:39.719577+00');


--
-- Data for Name: challenge_base_match_sessions; Type: TABLE DATA; Schema: private; Owner: postgres
--

INSERT INTO "private"."challenge_base_match_sessions" ("id", "user_id", "session_nonce_hash", "mode", "variation", "seed", "algorithm_version", "question_codes", "question_count", "sequence_hash", "rules_version", "allow_hearts", "status", "started_at", "expires_at", "completed_at", "result_id", "challenge_id", "event_id", "idempotency_key", "created_at") VALUES
	('98f25e06-f5bf-42c2-8bf6-782ce88ba037', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'f78ae971cb633986f6be9503af5aae399182bd497a9d08fd2d31a0144cee1dc0', 'world', '10', '22d07384b8ee82192f6bbc552ee7dace', 'server-sequence-v1', '["MZ", "JM", "GB", "CA", "AO", "NL", "LV", "CO", "SC", "KW"]', 10, '484696fa1c04d7ffd1adc06b6e59107213683f59bd5d128f923f866bc97236d8', 1, false, 'completed', '2026-07-30 01:31:12.859134+00', '2026-07-30 02:16:12.859134+00', '2026-07-30 01:31:36.224607+00', '3de175b5-722c-4179-8937-bab506ed4021', 'bb3760de-4f52-4ea1-b38d-e60c432fb235', 'fg_event_ms6u7y7h_1m0jxo3dlwy2o', 'fg_event_ms6u7y7h_1m0jxo3dlwy2o', '2026-07-30 01:31:12.859134+00');


--
-- Data for Name: challenge_configs; Type: TABLE DATA; Schema: private; Owner: postgres
--

INSERT INTO "private"."challenge_configs" ("challenge_id", "seed", "algorithm_version", "question_codes", "question_count", "rules_version", "allow_hearts", "scoring", "created_at", "sequence_hash", "base_match_id") VALUES
	('bb3760de-4f52-4ea1-b38d-e60c432fb235', '22d07384b8ee82192f6bbc552ee7dace', 'server-sequence-v1', '["MZ", "JM", "GB", "CA", "AO", "NL", "LV", "CO", "SC", "KW"]', 10, 1, false, '{"score": "correct_answers", "tie_breakers": ["score_desc", "correct_answers_desc", "elapsed_time_ms_asc", "best_streak_desc"]}', '2026-07-30 01:31:36.224607+00', '484696fa1c04d7ffd1adc06b6e59107213683f59bd5d128f923f866bc97236d8', '98f25e06-f5bf-42c2-8bf6-782ce88ba037');


--
-- Data for Name: challenge_participants; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."challenge_participants" ("id", "challenge_id", "user_id", "role", "status", "accepted_at", "started_at", "completed_at", "result_id", "event_id", "score", "correct_answers", "wrong_answers", "skipped_answers", "total_questions", "accuracy", "elapsed_time_ms", "best_streak", "created_at", "updated_at") VALUES
	('68432ecc-89a0-465a-ba86-0795b6fe6e3c', 'bb3760de-4f52-4ea1-b38d-e60c432fb235', '2ba1e49e-4d8b-4c43-a005-697426e97dff', 'creator', 'completed', '2026-07-30 01:31:12.859134+00', '2026-07-30 01:31:12.859134+00', '2026-07-30 01:31:36.224607+00', '3de175b5-722c-4179-8937-bab506ed4021', 'fg_event_ms6u7y7h_1m0jxo3dlwy2o', 4, 4, 6, 0, 10, 40.00, 20000, 2, '2026-07-30 01:31:36.224607+00', '2026-07-30 01:31:36.224607+00');


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

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 25, true);


--
-- PostgreSQL database dump complete
--

-- \unrestrict b2h5ieCYledjzkxAy8rbx20rs94gqoOvLwaUaCuLkKoNQLFZ7hpQG2UG5dwjSSv

RESET ALL;
