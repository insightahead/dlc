

CREATE DATABASE dlc_db;

\c dlc_db;


-- Create a schema if it does not exist
CREATE SCHEMA IF NOT EXISTS dlc;

-- Create a table for user profiles within the dlc schema
CREATE TABLE IF NOT EXISTS dlc.user_profiles (
    user_id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    country_id CHAR(2), -- ISO Alpha-2 country codes
    last_login TIMESTAMP WITH TIME ZONE,
    signup_date TIMESTAMP WITH TIME ZONE NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    birthdate DATE,
    is_email_confirmed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP 
);

CREATE TABLE IF NOT EXISTS dlc.instructor_profiles(
    instructor_id UUID PRIMARY KEY,
    user_id UUID ,
    biography TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dlc.course_templates (
    course_id UUID,
    instructor_id UUID,
    course_category_id VARCHAR(255) NOT NULL,
    primary_language_id VARCHAR(10) NOT NULL,
    title TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    currency_id VARCHAR(10) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (course_id, title)
);

CREATE TABLE IF NOT EXISTS dlc.courses (
    PRIMARY KEY (course_id, instructor_id, title),
    course_id UUID NOT NULL,
    instructor_id UUID NOT NULL,
    title TEXT NOT NULL,
    course_category_id VARCHAR(255) NOT NULL,
    primary_language_id VARCHAR(10) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    currency_id VARCHAR(10) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dlc.course_sales(
    sale_id UUID PRIMARY KEY,
    sale_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    course_id UUID NOT NULL,
    user_id UUID NOT NULL,
    sale_price DECIMAL(10, 2) NOT NULL,
    sale_currency_id CHAR(3) NOT NULL,
    coupon_id UUID,
    sale_channel VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Create a table for course engagement within the dlc schema
CREATE TABLE IF NOT EXISTS dlc.course_engagements (
    PRIMARY KEY (course_engagement_id, course_id, student_id),
    course_engagement_id UUID NOT NULL,
    course_id UUID NOT NULL,
    student_id UUID NOT NULL,
    progress INTEGER,
    number_questions_asked INTEGER,
    number_questions_answered INTEGER,
    enrollment_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_visited_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


-- CREATE TABLE IF NOT EXISTS dlc.course_categories (
--     category_id UUID PRIMARY KEY,
--     category_name VARCHAR(255) NOT NULL,
--     description TEXT,
--     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TABLE IF NOT EXISTS dlc.languages (
--     language_id UUID PRIMARY KEY,
--     language_name VARCHAR(255) NOT NULL,
--     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TABLE IF NOT EXISTS dlc.countries (
--     country_id CHAR(2) PRIMARY KEY, 
--     country_name VARCHAR(255) NOT NULL,
--     country_code VARCHAR(255) NOT NULL, -- ISO Alpha-2 country codes
--     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TABLE IF NOT EXISTS dlc.currencies (
--     currency_id CHAR(3) PRIMARY KEY,
--     currency_name VARCHAR(255) NOT NULL,
--     currency_sign VARCHAR(255) NOT NULL, 
--     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TABLE IF NOT EXISTS dlc.course_reviews(
--     review_id UUID PRIMARY KEY,
--     course_id UUID REFERENCES dlc.courses(course_id),
--     user_id UUID REFERENCES dlc.user_profiles(user_id),
--     rating INT NOT NULL,
--     review TEXT,
--     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );




CREATE INDEX idx_user_profile_user_id ON dlc.user_profiles(user_id);

CREATE INDEX idx_instructor_id ON dlc.instructor_profiles(instructor_id);
CREATE INDEX idx_instructor_user_id ON dlc.instructor_profiles(user_id);


/*
Function: dlc.update_updated_at_column()

Description: This function updates the "updated_at" column of a table with the current timestamp.

*/
CREATE OR REPLACE FUNCTION dlc.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*
Creates a trigger named "set_user_profiles_updated_at".
This trigger is used to update the "updated_at" column of the "user_profiles" table
whenever a row is inserted or updated in the "user_profiles" table.
*/
CREATE TRIGGER set_user_profiles_updated_at
BEFORE INSERT OR UPDATE ON dlc.user_profiles
FOR EACH ROW
EXECUTE FUNCTION dlc.update_updated_at_column();

/**
 * Sets the created_at timestamp of a row to the current time.
 */
CREATE OR REPLACE FUNCTION dlc.set_created_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.created_at IS NULL THEN
        NEW.created_at = NEW.updated_at;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*
Creates a trigger named "set_user_profiles_created_at".
This trigger sets the "created_at" column of the "user_profiles" table to the current timestamp
when a new row is inserted into the table.
*/
CREATE TRIGGER set_user_profiles_created_at
BEFORE INSERT ON dlc.user_profiles
FOR EACH ROW
EXECUTE FUNCTION dlc.set_created_at();

-- setup airbyte readonly user
CREATE USER airbyte PASSWORD 'password';
GRANT USAGE ON SCHEMA dlc TO airbyte;
GRANT SELECT ON ALL TABLES IN SCHEMA dlc TO airbyte;
ALTER DEFAULT PRIVILEGES IN SCHEMA dlc GRANT SELECT ON TABLES TO airbyte;

ALTER USER airbyte REPLICATION;
ALTER TABLE dlc.user_profiles REPLICA IDENTITY DEFAULT;

-- create replication slot, check if there isn't a better way to do this
-- SELECT pg_create_logical_replication_slot('airbyte_slot', 'pgoutput'); 

CREATE PUBLICATION airbyte_publication FOR TABLE dlc.user_profiles;

--- Data Insertion

-- INSERT INTO dlc.currencies (currency_id, currency_name, currency_sign) VALUES
-- ('USD', 'American Dollar', '$'),
-- ('AUD', 'Australian Dollar', 'au$'),
-- ('BRL', 'Brazilian Real', 'R$'),
-- ('GBP', 'British Pound', '£'),
-- ('CAD', 'Canadian Dollar', 'ca$'),
-- ('CLP', 'Chilean Peso', 'clp'),
-- ('COP', 'Colombian Peso', 'col$'),
-- ('EGP', 'Egyptian Pound', 'e£'),
-- ('EUR', 'Euro', '€'),
-- ('INR', 'Indian Rupee', '₹'),
-- ('IDR', 'Indonesian Rupiah', 'rp'),
-- ('ILS', 'Israel Shekel', '₪'),
-- ('JPY', 'Japanese Yen', '¥'),
-- ('MYR', 'Malaysian Ringgit', 'rm'),
-- ('MXN', 'Mexican Peso', 'me$'),
-- ('NGN', 'Nigerian Naira', '₦'),
-- ('NOK', 'Norway Krone', 'kr'),
-- ('PEN', 'Peruvian Sol', 's/.'),
-- ('PHP', 'Philippine Peso', '₱'),
-- ('PLN', 'Polish Zloty', 'zł'),
-- ('RON', 'Romanian Lei', 'ron'),
-- ('SGD', 'Singaporean Dollar', 's$'),
-- ('ZAR', 'South African Rand', 'r'),
-- ('KRW', 'South Korea Won', '₩'),
-- ('TWD', 'Taiwan New Dollar', 'nt$'),
-- ('THB', 'Thailand Baht', '฿'),
-- ('TRY', 'Turkish Lira', '₺'),
-- ('RUB', 'Russian Ruble', '₽'),
-- ('VND', 'Vietnam Dong', '₫');


-- INSERT INTO dlc.languages (language_id, language_name) VALUES
-- ('af_ZA', 'Afrikaans'),
-- ('sq_AL', 'Shqip'),
-- ('ar_AR', 'العربية'),
-- ('hy_AM', 'Հայերեն'),
-- ('ay_BO', 'Aymar aru'),
-- ('az_AZ', 'Azərbaycan dili'),
-- ('eu_ES', 'Euskara'),
-- ('bn_IN', 'Bangla'),
-- ('bs_BA', 'Bosanski'),
-- ('bg_BG', 'Български'),
-- ('my_MM', 'မြန်မာဘာသာ'),
-- ('ca_ES', 'Català'),
-- ('ck_US', 'Cherokee'),
-- ('hr_HR', 'Hrvatski'),
-- ('cs_CZ', 'Čeština'),
-- ('da_DK', 'Dansk'),
-- ('nl_NL', 'Nederlands'),
-- ('nl_BE', 'Nederlands (België)'),
-- ('en_IN', 'English (India)'),
-- ('en_GB', 'English (UK)'),
-- ('en_US', 'English (US)'),
-- ('et_EE', 'Eesti'),
-- ('fo_FO', 'Føroyskt'),
-- ('tl_PH', 'Filipino'),
-- ('fi_FI', 'Suomi'),
-- ('fr_CA', 'Français (Canada)'),
-- ('fr_FR', 'Français (France)'),
-- ('fy_NL', 'Frysk'),
-- ('gl_ES', 'Galego'),
-- ('ka_GE', 'ქართული'),
-- ('de_DE', 'Deutsch'),
-- ('el_GR', 'Ελληνικά'),
-- ('gn_PY', 'Avañe''ẽ'),
-- ('gu_IN', 'ગુજરાતી'),
-- ('ht_HT', 'Ayisyen'),
-- ('he_IL', '‏עברית‏'),
-- ('hi_IN', 'हिन्दी'),
-- ('hu_HU', 'Magyar'),
-- ('is_IS', 'Íslenska'),
-- ('id_ID', 'Bahasa Indonesia'),
-- ('ga_IE', 'Gaeilge'),
-- ('it_IT', 'Italiano'),
-- ('ja_JP', '日本語'),
-- ('jv_ID', 'Basa Jawa'),
-- ('kn_IN', 'Kannaḍa'),
-- ('kk_KZ', 'Қазақша'),
-- ('km_KH', 'Khmer'),
-- ('ko_KR', '한국어'),
-- ('ku_TR', 'Kurdî'),
-- ('lv_LV', 'Latviešu'),
-- ('li_NL', 'Lèmbörgs'),
-- ('lt_LT', 'Lietuvių'),
-- ('mk_MK', 'Македонски'),
-- ('mg_MG', 'Malagasy'),
-- ('ms_MY', 'Bahasa Melayu'),
-- ('ml_IN', 'Malayāḷam'),
-- ('mt_MT', 'Malti'),
-- ('mr_IN', 'मराठी'),
-- ('mn_MN', 'Монгол'),
-- ('ne_NP', 'नेपाली'),
-- ('se_NO', 'Davvisámegiella'),
-- ('nb_NO', 'Norsk (bokmål)'),
-- ('nn_NO', 'Norsk (nynorsk)'),
-- ('ps_AF', 'پښتو'),
-- ('fa_IR', 'فارسی'),
-- ('pl_PL', 'Polski'),
-- ('pt_BR', 'Português (Brasil)'),
-- ('pt_PT', 'Português (Portugal)'),
-- ('pa_IN', 'ਪੰਜਾਬੀ'),
-- ('qu_PE', 'Qhichwa'),
-- ('ro_RO', 'Română'),
-- ('rm_CH', 'Rumantsch'),
-- ('ru_RU', 'Русский'),
-- ('sa_IN', 'संस्कृतम्'),
-- ('sr_RS', 'Српски'),
-- ('zh_CN', '中文(简体)'),
-- ('sk_SK', 'Slovenčina'),
-- ('sl_SI', 'Slovenščina'),
-- ('so_SO', 'Soomaaliga'),
-- ('es_LA', 'Español'),
-- ('es_CL', 'Español (Chile)'),
-- ('es_CO', 'Español (Colombia)'),
-- ('es_MX', 'Español (México)'),
-- ('es_ES', 'Español (España)'),
-- ('es_VE', 'Español (Venezuela)'),
-- ('sw_KE', 'Kiswahili'),
-- ('sv_SE', 'Svenska'),
-- ('sy_SY', 'Leššānā Suryāyā'),
-- ('tg_TJ', 'тоҷикӣ, تاجیکی‎, tojikī'),
-- ('ta_IN', 'தமிழ்'),
-- ('tt_RU', 'татарча / Tatarça / تاتارچا'),
-- ('te_IN', 'Telugu'),
-- ('th_TH', 'ภาษาไทย'),
-- ('zh_HK', '中文(香港)'),
-- ('zh_TW', '中文 (繁體)'),
-- ('tr_TR', 'Türkçe'),
-- ('uk_UA', 'Українська'),
-- ('ur_PK', 'اردو'),
-- ('uz_UZ', 'O''zbek'),
-- ('vi_VN', 'Tiếng Việt'),
-- ('cy_GB', 'Cymraeg'),
-- ('xh_ZA', 'isiXhosa'),
-- ('yi_DE', 'ייִדיש'),
-- ('zu_ZA', 'isiZulu');
