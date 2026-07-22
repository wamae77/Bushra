import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'Bushra Mobile';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '18';
  static const String appDescription = 'Bushra Mobile Banking Application for Somalia';
  static const String appAuthor = 'Bushra Bank';
  static const int appIdleTimeMinutes = 3; // Time in minutes after which the user is considered idle
  static const String certificateHost ='ep.bbbank.so';
  static const String isProdBuild = 'false';
  static const bool allowDeveloperMode = false; // Set to true if you want to allow dev mode
  static const bool allowExternalStorage = false; // Set to true to allow app installation to external storage
  // API
  static const String baseUrl = 'https://gen-ms01.bbbank.so:43964';
  static const String baseUrlToken = 'https://gen-ms01.bbbank.so:9443';
  // API Endpoints
  static const String endpointFetchProfileImage = "/bb/mobile/customer/getprofilephoto/1.0.0/";
  // App Keys
  static const String apiKey ='eyJ4NXQjUzI1NiI6Ik5XUXdPVFJrTWpBNU9XRmpObVUyTnpCbE5UTTNaRFV3T0RVellqWXdabUpsWlROa1pEQTRPRFU0WlRVd1pHSXdObVV5TW1abVpUTmhaRGt5TmpRMlpBPT0iLCJraWQiOiJnYXRld2F5X2NlcnRpZmljYXRlX2FsaWFzIiwidHlwIjoiSldUIiwiYWxnIjoiUlMyNTYifQ==.eyJzdWIiOiJhZG1pbkBjYXJib24uc3VwZXIiLCJhcHBsaWNhdGlvbiI6eyJpZCI6MSwidXVpZCI6IjYyOTgzMzU2LTIyMzMtNGI4NC04NWIzLWY3ZWM1YzY4MzMyYyJ9LCJpc3MiOiJodHRwczpcL1wvMTAuMTcxLjEwLjIxOjk0NDNcL29hdXRoMlwvdG9rZW4iLCJrZXl0eXBlIjoiU0FOREJPWCIsInBlcm1pdHRlZFJlZmVyZXIiOiIiLCJ0b2tlbl90eXBlIjoiYXBpS2V5IiwicGVybWl0dGVkSVAiOiIiLCJpYXQiOjE3Mzg5MjE4NjcsImp0aSI6IjFlNDc1MmU1LWM3OGEtNDRiMy1iMWVlLWJjZjliN2VhZGIyNCJ9.j2WqOd4FyJNzL5nb58bLX6G6vtj3STsH3kwssxuNaTN9QOQ-6Dhsv7j_gNZxR8YvSWSLs80MWWb-elRq2QB_uzd-vQY1rnoFilYy1dMdpHD_9R_JPtNKAR7r3aL0Tf5FSBbkmAtiJozKfnopyAXU5aXN9VTMtmndhajNqC2x3eNatMwmhEc13UER2FucIkAEPD5hgdEg9iRBbMHsF9CTRt-e3qMw-4a6lHf2UFJv54vVaUcUxJBkPEW91RJzzL6_am3erZoqmeg6NIyssXaHdNe9tsn483VdtWjiuWOW0wZhZfSSr2H-AtOFGq23F-S5F5vDIBCahFY0LXNWYbCSPw==';
  static const String clientId = 'me4hI_VdjagtBynjGSV9il8aYXka';
  static const String clientSecret = 'okQiuU8BMIAdpGzXLHP1lN22u3Ya';
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double avatarRadius = 50.0;
  // Colors
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color accentColor = Color(0xFFFF5722);
  // Others Default Values
  static const String defaultLanguage = 'en';
  static const String defaultPhoneNumber = '252718908314';
  static const String defaultCountryCode = 'SO';
  static const String defaultCountryName = 'Somalia';
  static const String defaultCurrencyCode = 'USD';
  static const String defaultCountryDialCode = '+252';
  static const String defaultCountryFlag = 'assets/icons/so.svg';
  static const String defaultCountryFlagUrl = 'https://restcountries.com/v3.1/alpha/so';
  static const String defaultCountryFlagUrl2 = 'https://restcountries.com/v3.1/alpha/SOM';
  static const String defaultCountryFlagUrl3 = 'https://restcountries.com/v3.1/alpha/SOM?fullText=true';
  static const String defaultCountryFlagUrl4 = 'https://restcountries.com/v3.1/alpha/SOM?fullText=true&fields=flags';
  static const String defaultDateFormat = 'yyyy-MM-dd';
  static const String defaultDateFormatWithTime = 'yyyy-MM-dd HH:mm:ss';
  static const String defaultDateFormatWithTimeZone = 'yyyy-MM-dd HH:mm:ss Z';
  static const String defaultDateFormatWithTimeZoneAndLocale = 'yyyy-MM-dd HH:mm:ss ZZZZ';
  // Add http client configuration and connection timeout
  static const Duration connectionTimeout = Duration(seconds: 60);
  static const Duration readTimeout = Duration(seconds: 60);
  static const Duration writeTimeout = Duration(seconds: 60);
}
