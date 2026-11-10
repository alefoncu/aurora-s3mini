package com.scratch.ios7launcher;

import android.content.SharedPreferences;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.TimeZone;

/**
 * Today weather from Open-Meteo (no key, https). The city is whatever the user set with "tiempo <ciudad>" in the search,
 * otherwise the city of the device time zone (Europe/Madrid -> Madrid). Nothing but that city name is sent.
 */
final class Weather {
    static final long MAX_AGE = 30 * 60 * 1000L;
    String city = "", desc = "";
    int temp, hi, lo, code, rain = -1;   // rain: today's max precipitation probability %, -1 unknown
    boolean day = true, ok;
    long ts;

    static Weather cached(SharedPreferences p) {
        Weather w = new Weather();
        String j = p.getString("weather", "");
        if (j.isEmpty()) return w;
        try {
            JSONObject o = new JSONObject(j);
            w.city = o.getString("city"); w.temp = o.getInt("t"); w.hi = o.getInt("hi"); w.lo = o.getInt("lo");
            w.code = o.getInt("code"); w.day = o.getBoolean("day"); w.ts = o.getLong("ts"); w.rain = o.optInt("pp", -1); w.ok = true; w.desc = describe(w.code);
        } catch (Exception e) { w.ok = false; }
        return w;
    }

    static String defaultCity() {
        String id = TimeZone.getDefault().getID();
        int i = id.lastIndexOf('/');
        return (i >= 0 ? id.substring(i + 1) : id).replace('_', ' ');
    }

    /** Blocking: call from a worker thread. Returns null on failure. */
    static Weather fetch(String city) {
        try {
            JSONObject g = new JSONObject(get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=es&name=" + URLEncoder.encode(city, "UTF-8")));
            JSONArray rs = g.optJSONArray("results");
            if (rs == null || rs.length() == 0) return null;
            JSONObject r = rs.getJSONObject(0);
            JSONObject f = new JSONObject(get("https://api.open-meteo.com/v1/forecast?latitude=" + r.getDouble("latitude") + "&longitude=" + r.getDouble("longitude")
                    + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"));
            JSONObject cur = f.getJSONObject("current"), day = f.getJSONObject("daily");
            Weather w = new Weather();
            w.city = r.getString("name");
            w.temp = (int) Math.round(cur.getDouble("temperature_2m"));
            w.code = cur.getInt("weather_code");
            w.day = cur.getInt("is_day") == 1;
            w.hi = (int) Math.round(day.getJSONArray("temperature_2m_max").getDouble(0));
            w.lo = (int) Math.round(day.getJSONArray("temperature_2m_min").getDouble(0));
            org.json.JSONArray pp = day.optJSONArray("precipitation_probability_max");
            if (pp != null && pp.length() > 0 && !pp.isNull(0)) w.rain = pp.getInt(0);
            w.desc = describe(w.code); w.ts = System.currentTimeMillis(); w.ok = true;
            return w;
        } catch (Exception e) { return null; }
    }

    void save(SharedPreferences p) {
        try {
            p.edit().putString("weather", new JSONObject().put("city", city).put("t", temp).put("hi", hi).put("lo", lo)
                    .put("code", code).put("day", day).put("ts", ts).put("pp", rain).toString()).apply();
        } catch (Exception e) { }
    }

    private static String get(String u) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(u).openConnection();
        c.setConnectTimeout(8000); c.setReadTimeout(8000);
        try (InputStream in = c.getInputStream()) {
            java.io.ByteArrayOutputStream o = new java.io.ByteArrayOutputStream();
            byte[] b = new byte[4096]; int n;
            while ((n = in.read(b)) > 0) o.write(b, 0, n);
            return o.toString("UTF-8");
        } finally { c.disconnect(); }
    }

    /** Glyph kind for the WMO weather code. */
    String kind() {
        if (code == 0) return day ? "sun" : "moon";
        if (code <= 2) return day ? "partly" : "cloud";
        if (code == 3) return "cloud";
        if (code == 45 || code == 48) return "fog";
        if (code >= 95) return "storm";
        if ((code >= 71 && code <= 77) || code == 85 || code == 86) return "snow";
        return "rain";
    }

    static String describe(int c) {
        if (c == 0) return "Despejado";
        if (c == 1) return "Mayormente despejado";
        if (c == 2) return "Parcialmente nublado";
        if (c == 3) return "Nublado";
        if (c == 45 || c == 48) return "Niebla";
        if (c >= 51 && c <= 57) return "Llovizna";
        if (c >= 61 && c <= 67) return "Lluvia";
        if (c >= 71 && c <= 77) return "Nieve";
        if (c >= 80 && c <= 82) return "Chubascos";
        if (c == 85 || c == 86) return "Chubascos de nieve";
        if (c >= 95) return "Tormenta";
        return "Variable";
    }
}
