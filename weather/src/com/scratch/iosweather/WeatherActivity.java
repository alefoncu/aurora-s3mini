package com.scratch.iosweather;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.InputType;
import android.util.TypedValue;
import android.view.*;
import android.view.animation.DecelerateInterpolator;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Wallpaper-backed weather, using only framework widgets and Open-Meteo. */
public class WeatherActivity extends Activity {
    private float density;
    private boolean night;
    private int ink, subtle, glass, stroke, generation;
    private LinearLayout column;
    private TextView cityTitle, temperature, description, extremes, status;
    private SharedPreferences prefs;
    private String city;
    private Forecast displayed;
    private final ExecutorService network = Executors.newSingleThreadExecutor();
    private volatile HttpURLConnection activeConnection;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        density = getResources().getDisplayMetrics().density;
        night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        ink = night ? Color.WHITE : 0xFF14123A;
        subtle = night ? 0xB3FFFFFF : 0x9914123A;
        glass = night ? 0x2EFFFFFF : 0x66FFFFFF;
        stroke = night ? 0x38FFFFFF : 0xB3FFFFFF;
        prefs = getSharedPreferences("weather", MODE_PRIVATE);
        String zone = TimeZone.getDefault().getID();
        city = prefs.getString("city", zone.substring(zone.lastIndexOf('/') + 1).replace('_', ' '));
        if (city == null || city.trim().isEmpty()) city = "Madrid";
        buildScreen();
        try {
            JSONObject cache = new JSONObject(prefs.getString("cache", ""));
            if (city.equals(cache.optString("city"))) {
                Forecast data = new Forecast(cache.optJSONObject("forecast"));
                if (data.usable()) { displayed = data; render(data); }
            }
        } catch (Exception ignored) { }
        fetch(city, false);
    }

    private int dp(float value) { return (int) (value * density + 0.5f); }
    private TextView label(String value, int size, boolean thin) {
        TextView view = new TextView(this);
        view.setText(value); view.setTextColor(ink);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, size);
        view.setTypeface(Typeface.create(thin ? "sans-serif-thin" : "sans-serif-light", Typeface.NORMAL));
        return view;
    }
    private TextView centered(String value, int size) {
        TextView view = label(value, size, false); view.setGravity(Gravity.CENTER); return view;
    }
    private void buildScreen() {
        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(Color.TRANSPARENT);
        window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        FrameLayout root = new FrameLayout(this);
        View scrim = new View(this); scrim.setBackgroundColor(night ? 0x6614123A : 0x33F6F5FF);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));
        ScrollView scroll = new ScrollView(this); scroll.setClipToPadding(true); scroll.setFillViewport(true);
        column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL);
        int top = getResources().getIdentifier("status_bar_height", "dimen", "android");
        int inset = top == 0 ? dp(24) : getResources().getDimensionPixelSize(top);
        scroll.setPadding(0, inset, 0, 0);
        column.setPadding(dp(20), dp(20), dp(20), dp(32));
        scroll.addView(column, new ScrollView.LayoutParams(-1, -2));
        root.addView(scroll, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout header = new LinearLayout(this); header.setOrientation(LinearLayout.VERTICAL);
        cityTitle = label(city, 22, true); cityTitle.setGravity(Gravity.CENTER);
        cityTitle.setPadding(0, dp(6), 0, dp(6)); cityTitle.setContentDescription("Cambiar ciudad");
        cityTitle.setOnClickListener(v -> changeCity()); header.addView(cityTitle, new LinearLayout.LayoutParams(-1, -2));
        temperature = label("—°", 88, true); temperature.setGravity(Gravity.CENTER);
        temperature.setIncludeFontPadding(false); temperature.setContentDescription("Actualizar el tiempo");
        temperature.setOnClickListener(v -> fetch(city, false)); header.addView(temperature, new LinearLayout.LayoutParams(-1, -2));
        description = centered("Cargando…", 19); header.addView(description);
        extremes = centered("Máx —° · Mín —°", 16); extremes.setPadding(0, dp(6), 0, 0); header.addView(extremes);
        status = centered("", 12); status.setTextColor(subtle); status.setPadding(0, dp(4), 0, dp(16)); header.addView(status);
        column.addView(header, new LinearLayout.LayoutParams(-1, -2));
        setContentView(root);
    }
    private LinearLayout card(String heading, int order) {
        LinearLayout card = new LinearLayout(this); card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(16), dp(16), dp(16));
        GradientDrawable bg = new GradientDrawable(); bg.setColor(glass); bg.setCornerRadius(dp(24));
        bg.setStroke(Math.max(1, dp(0.5f)), stroke); card.setBackground(bg);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2); params.bottomMargin = dp(14);
        column.addView(card, params);
        TextView title = label(heading, 12, false); title.setTextColor(subtle); title.setLetterSpacing(0.08f);
        title.setPadding(0, 0, 0, dp(12)); card.addView(title);
        card.setAlpha(0f); card.setTranslationY(dp(24));
        card.animate().alpha(1f).translationY(0f).setStartDelay(order * 70L).setDuration(420)
                .setInterpolator(new DecelerateInterpolator()).start();
        return card;
    }
    private void render(Forecast data) {
        cityTitle.setText(city); temperature.setText(degrees(data.temp));
        description.setText(description(data.code));
        Day today = data.days.isEmpty() ? null : data.days.get(0);
        extremes.setText("Máx " + degrees(today == null ? Double.NaN : today.max) + " · Mín " + degrees(today == null ? Double.NaN : today.min));
        status.setText("");
        while (column.getChildCount() > 1) column.removeViewAt(1);
        LinearLayout hoursCard = card("PRÓXIMAS HORAS", 0);
        HorizontalScrollView scroll = new HorizontalScrollView(this); scroll.setHorizontalScrollBarEnabled(false);
        LinearLayout hours = new LinearLayout(this);
        for (Hour hour : data.hours) {
            LinearLayout cell = new LinearLayout(this); cell.setOrientation(LinearLayout.VERTICAL); cell.setGravity(Gravity.CENTER);
            cell.addView(centered(hour.time.length() >= 13 ? hour.time.substring(11, 13) : "—", 13));
            cell.addView(new GlyphView(WeatherGlyph.kind(hour.code, hour.day)), new LinearLayout.LayoutParams(dp(42), dp(45)));
            cell.addView(centered(degrees(hour.temp), 20));
            TextView rain = centered(valid(hour.rain) && hour.rain >= 20 ? Math.round(hour.rain) + "%" : "", 11);
            rain.setTextColor(0xFF74BFFF); cell.addView(rain, new LinearLayout.LayoutParams(-1, dp(22)));
            hours.addView(cell, new LinearLayout.LayoutParams(dp(62), -2));
        }
        if (data.hours.isEmpty()) hours.addView(label("Sin datos horarios", 15, false));
        scroll.addView(hours, new HorizontalScrollView.LayoutParams(-2, -2)); hoursCard.addView(scroll);
        LinearLayout chart = card("TEMPERATURA", 1);
        chart.addView(new TemperatureChart(data.hours), new LinearLayout.LayoutParams(-1, dp(150)));
        LinearLayout days = card("5 DÍAS", 2);
        double low = Double.POSITIVE_INFINITY, high = Double.NEGATIVE_INFINITY;
        for (Day day : data.days) { if (valid(day.min)) low = Math.min(low, day.min); if (valid(day.max)) high = Math.max(high, day.max); }
        for (int i = 0; i < data.days.size(); i++) {
            Day day = data.days.get(i);
            LinearLayout row = new LinearLayout(this); row.setGravity(Gravity.CENTER_VERTICAL);
            TextView name = label(i == 0 ? "Hoy" : weekday(day.date), 16, false);
            row.addView(name, new LinearLayout.LayoutParams(dp(44), dp(42)));
            name.setGravity(Gravity.CENTER_VERTICAL);
            row.addView(new GlyphView(WeatherGlyph.kind(day.code, true)), new LinearLayout.LayoutParams(dp(37), dp(40)));
            TextView min = centered(degrees(day.min), 16); min.setTextColor(subtle);
            row.addView(min, new LinearLayout.LayoutParams(dp(43), -2));
            row.addView(new RangeView(day.min, day.max, low, high), new LinearLayout.LayoutParams(0, dp(30), 1));
            row.addView(centered(degrees(day.max), 16), new LinearLayout.LayoutParams(dp(43), -2)); days.addView(row);
        }
        if (data.days.isEmpty()) days.addView(label("Sin datos diarios", 15, false));
        LinearLayout stats = card("AHORA", 3);
        LinearLayout cells = new LinearLayout(this);
        stat(cells, "SENSACIÓN", degrees(data.apparent));
        stat(cells, "HUMEDAD", number(data.humidity, "%"));
        stat(cells, "VIENTO", number(data.wind, " km/h")); stats.addView(cells);
        TextView sun = label("SOL   ↑ " + time(today == null ? "" : today.sunrise) + "    ↓ " + time(today == null ? "" : today.sunset), 15, false);
        sun.setTextColor(subtle); sun.setPadding(0, dp(18), 0, 0); stats.addView(sun);
    }
    private void stat(LinearLayout row, String title, String value) {
        LinearLayout cell = new LinearLayout(this); cell.setOrientation(LinearLayout.VERTICAL);
        TextView titleView = centered(title, 10); titleView.setTextColor(subtle); cell.addView(titleView);
        TextView amount = centered(value, 21); amount.setPadding(0, dp(8), 0, 0); cell.addView(amount);
        row.addView(cell, new LinearLayout.LayoutParams(0, -2, 1));
    }
    private void changeCity() {
        EditText input = new EditText(this); input.setSingleLine(true); input.setText(city); input.selectAll();
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_WORDS);
        input.setPadding(dp(20), dp(12), dp(20), dp(12));
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle("Cambiar ciudad").setView(input)
                .setNegativeButton("Cancelar", null).setPositiveButton("Guardar", null).create();
        dialog.setOnShowListener(v -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(button -> {
            String requested = input.getText().toString().trim();
            if (requested.isEmpty() || requested.length() > 120) { input.setError("Introduce una ciudad válida"); return; }
            dialog.dismiss(); fetch(requested, true);
        })); dialog.show();
    }

    private void fetch(final String requested, final boolean changing) {
        if (network.isShutdown()) return;
        final int version = ++generation;
        status.setText("Actualizando…");
        network.execute(() -> {
            try {
                JSONObject geo = getJson("https://geocoding-api.open-meteo.com/v1/search?count=1&language=es&name=" + URLEncoder.encode(requested, "UTF-8"));
                JSONArray results = geo.optJSONArray("results");
                JSONObject place = results == null ? null : results.optJSONObject(0);
                if (place == null) {
                    runOnUiThread(() -> {
                        if (!current(version)) return;
                        status.setText(displayed == null ? "Ciudad no encontrada" : "");
                        Toast.makeText(this, "Ciudad no encontrada", Toast.LENGTH_SHORT).show();
                    }); return;
                }
                double lat = place.optDouble("latitude", Double.NaN), lon = place.optDouble("longitude", Double.NaN);
                if (!valid(lat) || !valid(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) throw new IOException("Coordinates");
                JSONObject json = getJson("https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
                        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
                        + "&hourly=temperature_2m,weather_code,precipitation_probability"
                        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=5");
                Forecast data = new Forecast(json);
                if (!data.usable()) throw new IOException("Empty forecast");
                JSONObject cache = new JSONObject(); cache.put("city", requested); cache.put("forecast", json);
                String serialized = cache.toString();
                runOnUiThread(() -> {
                    if (!current(version)) return;
                    city = requested; displayed = data;
                    prefs.edit().putString("city", city).putString("cache", serialized).apply(); render(data);
                });
            } catch (Exception failure) {
                runOnUiThread(() -> {
                    if (!current(version)) return;
                    status.setText("Sin conexión");
                    if (displayed == null) description.setText("Toca la temperatura para reintentar");
                    if (changing) Toast.makeText(this, "No se pudo actualizar la ciudad", Toast.LENGTH_SHORT).show();
                });
            }
        });
    }
    private boolean current(int version) { return version == generation && !isFinishing() && !isDestroyed(); }
    private JSONObject getJson(String address) throws Exception {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException();
        HttpURLConnection connection = (HttpURLConnection) new URL(address).openConnection();
        activeConnection = connection;
        connection.setConnectTimeout(12000); connection.setReadTimeout(12000);
        connection.setRequestProperty("Accept", "application/json");
        try {
            if (connection.getResponseCode() != 200) throw new IOException("HTTP response");
            try (Reader reader = new InputStreamReader(connection.getInputStream(), "UTF-8")) {
                char[] buffer = new char[4096]; StringBuilder body = new StringBuilder(); int count;
                while ((count = reader.read(buffer)) != -1) {
                    if (Thread.currentThread().isInterrupted() || body.length() + count > 2000000) throw new IOException("Response limit");
                    body.append(buffer, 0, count);
                }
                return new JSONObject(body.toString());
            }
        } finally { connection.disconnect(); activeConnection = null; }
    }

    static boolean valid(double value) { return !Double.isNaN(value) && !Double.isInfinite(value); }
    private static String number(double value, String unit) { return valid(value) ? Math.round(value) + unit : "—"; }
    private static String degrees(double value) { return number(value, "°"); }
    private static String time(String value) { return value.length() >= 16 ? value.substring(11, 16) : "—:—"; }
    private static String weekday(String value) {
        try {
            SimpleDateFormat parser = new SimpleDateFormat("yyyy-MM-dd", Locale.US); parser.setLenient(false);
            Date date = parser.parse(value);
            Calendar c = Calendar.getInstance(); c.setTime(date);
            return new String[]{"dom", "lun", "mar", "mié", "jue", "vie", "sáb"}[c.get(Calendar.DAY_OF_WEEK) - 1];
        } catch (Exception ignored) { return "—"; }
    }
    static String description(int code) {
        if (code == 0) return "Despejado";
        if (code == 1) return "Mayormente despejado";
        if (code == 2) return "Parcialmente nublado";
        if (code == 3) return "Nublado";
        if (code == 45 || code == 48) return "Niebla";
        if (code >= 51 && code <= 57) return "Llovizna";
        if (code >= 61 && code <= 67) return "Lluvia";
        if (code >= 71 && code <= 77) return "Nieve";
        if (code >= 80 && code <= 82) return "Chubascos";
        if (code == 85 || code == 86) return "Chubascos de nieve";
        if (code >= 95) return "Tormenta";
        return "Sin datos";
    }
    private static JSONObject object(JSONObject obj, String key) {
        JSONObject result = obj == null ? null : obj.optJSONObject(key); return result == null ? new JSONObject() : result;
    }
    private static double value(JSONObject obj, String key) { return obj.optDouble(key, Double.NaN); }
    private static double at(JSONObject obj, String key, int index) {
        JSONArray values = obj.optJSONArray(key); return values == null ? Double.NaN : values.optDouble(index, Double.NaN);
    }
    private static String stringAt(JSONObject obj, String key, int index) {
        JSONArray values = obj.optJSONArray(key); return values == null ? "" : values.optString(index, "");
    }
    private static int codeAt(JSONObject obj, int index) {
        double value = at(obj, "weather_code", index); return valid(value) ? (int) value : -1;
    }
    private static double temp(double value) { return valid(value) && value >= -150 && value <= 150 ? value : Double.NaN; }
    private static class Hour { String time; double temp, rain; int code; boolean day; }
    private static class Day { String date, sunrise, sunset; double min, max; int code; }
    private static class Forecast {
        double temp, apparent, humidity, wind; int code;
        final List<Hour> hours = new ArrayList<>(); final List<Day> days = new ArrayList<>();
        Forecast(JSONObject json) {
            JSONObject current = object(json, "current"), hourly = object(json, "hourly"), daily = object(json, "daily");
            temp = temp(value(current, "temperature_2m")); apparent = temp(value(current, "apparent_temperature"));
            humidity = value(current, "relative_humidity_2m"); wind = value(current, "wind_speed_10m");
            if (humidity < 0 || humidity > 100) humidity = Double.NaN;
            if (wind < 0 || wind > 1000) wind = Double.NaN;
            code = current.optInt("weather_code", -1);
            JSONArray dates = daily.optJSONArray("time");
            for (int i = 0; dates != null && i < Math.min(5, dates.length()); i++) {
                Day day = new Day(); day.date = dates.optString(i, ""); day.code = codeAt(daily, i);
                day.min = temp(at(daily, "temperature_2m_min", i)); day.max = temp(at(daily, "temperature_2m_max", i));
                day.sunrise = stringAt(daily, "sunrise", i); day.sunset = stringAt(daily, "sunset", i); days.add(day);
            }
            String now = current.optString("time", "");
            if (now.length() < 13) {
                int offset = json == null ? 0 : json.optInt("utc_offset_seconds", 0);
                SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH", Locale.US);
                format.setTimeZone(TimeZone.getTimeZone("UTC")); now = format.format(new Date(System.currentTimeMillis() + offset * 1000L));
            } else now = now.substring(0, 13);
            JSONArray times = hourly.optJSONArray("time");
            for (int i = 0; times != null && i < Math.min(times.length(), 240) && hours.size() < 24; i++) {
                String stamp = times.optString(i, "");
                if (stamp.length() < 16 || stamp.substring(0, 13).compareTo(now) < 0) continue;
                Hour hour = new Hour(); hour.time = stamp; hour.temp = temp(at(hourly, "temperature_2m", i));
                hour.rain = at(hourly, "precipitation_probability", i);
                if (hour.rain < 0 || hour.rain > 100) hour.rain = Double.NaN;
                hour.code = codeAt(hourly, i);
                int hourOfDay = 12; try { hourOfDay = Integer.parseInt(stamp.substring(11, 13)); } catch (Exception ignored) { }
                hour.day = hourOfDay >= 7 && hourOfDay < 20;
                for (Day day : days) if (stamp.startsWith(day.date) && day.sunrise.length() >= 16 && day.sunset.length() >= 16) {
                    hour.day = stamp.compareTo(day.sunrise) >= 0 && stamp.compareTo(day.sunset) < 0; break;
                }
                if (hours.isEmpty() && stamp.substring(0, 13).equals(now) && current.has("is_day")) hour.day = current.optInt("is_day", 1) == 1;
                hours.add(hour);
            }
        }
        boolean usable() { return valid(temp); }
    }

    private class GlyphView extends View {
        final String kind;
        GlyphView(String kind) { super(WeatherActivity.this); this.kind = kind; setContentDescription(kind); setLayerType(LAYER_TYPE_SOFTWARE, null); }
        @Override protected void onDraw(Canvas canvas) {
            WeatherGlyph.draw(canvas, kind, getWidth() / 2f, getHeight() / 2f, Math.min(getWidth(), getHeight()) * 0.72f, ink);
        }
    }
    private class RangeView extends View {
        final double min, max, low, high; final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        RangeView(double min, double max, double low, double high) { super(WeatherActivity.this); this.min = min; this.max = max; this.low = low; this.high = high; }
        @Override protected void onDraw(Canvas canvas) {
            float left = dp(3), right = getWidth() - dp(3), y = getHeight() / 2f;
            if (right <= left) return;
            paint.setStrokeWidth(dp(5)); paint.setStrokeCap(Paint.Cap.ROUND); paint.setShader(null); paint.setColor(night ? 0x18FFFFFF : 0x1014123A);
            canvas.drawLine(left, y, right, y, paint);
            if (!valid(min) || !valid(max) || !valid(low) || !valid(high)) return;
            double span = Math.max(1, high - low);
            float a = left + (float) ((min - low) / span) * (right - left);
            float b = left + (float) ((max - low) / span) * (right - left);
            paint.setShader(new LinearGradient(left, y, right, y, 0xFF70BFFF, 0xFFFFB16B, Shader.TileMode.CLAMP));
            canvas.drawLine(a, y, Math.max(a + 1, b), y, paint); paint.setShader(null);
        }
    }
    private class TemperatureChart extends View {
        final List<Hour> hours; final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        TemperatureChart(List<Hour> hours) { super(WeatherActivity.this); this.hours = hours; setContentDescription("Temperatura de las próximas 24 horas"); }
        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            double low = Double.POSITIVE_INFINITY, high = Double.NEGATIVE_INFINITY; int lo = -1, hi = -1;
            for (int i = 0; i < hours.size(); i++) { double t = hours.get(i).temp; if (!valid(t)) continue;
                if (t < low) { low = t; lo = i; } if (t > high) { high = t; hi = i; }
            }
            if (lo < 0) {
                paint.setColor(subtle); paint.setTextSize(dp(14)); paint.setTypeface(Typeface.create("sans-serif-light", 0));
                canvas.drawText("Sin datos de temperatura", dp(8), getHeight() / 2f, paint); return;
            }
            int n = hours.size(); float[] x = new float[n], y = new float[n];
            float left = dp(20), right = Math.max(left + 1, getWidth() - dp(20)), top = dp(28), bottom = getHeight() - dp(34);
            double span = Math.max(2, high - low), middle = (high + low) / 2;
            for (int i = 0; i < n; i++) {
                x[i] = left + (right - left) * i / Math.max(1, n - 1);
                y[i] = valid(hours.get(i).temp) ? bottom - (float) ((hours.get(i).temp - middle + span / 2) / span) * (bottom - top) : Float.NaN;
            }
            int start = 0;
            while (start < n) {
                while (start < n && Float.isNaN(y[start])) start++;
                if (start == n) break;
                Path path = new Path(); path.moveTo(x[start], y[start]); int end = start;
                while (end + 1 < n && !Float.isNaN(y[end + 1])) {
                    float half = (x[end] + x[end + 1]) / 2;
                    path.cubicTo(half, y[end], half, y[end + 1], x[end + 1], y[end + 1]); end++;
                }
                Path fill = new Path(path); fill.lineTo(x[end], bottom + dp(8)); fill.lineTo(x[start], bottom + dp(8)); fill.close();
                paint.setStyle(Paint.Style.FILL);
                paint.setShader(new LinearGradient(0, top, 0, bottom + dp(8), night ? 0x40FFFFFF : 0x3014123A, Color.TRANSPARENT, Shader.TileMode.CLAMP));
                canvas.drawPath(fill, paint); paint.setShader(null);
                paint.setColor(ink); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(dp(2)); canvas.drawPath(path, paint);
                start = end + 1;
            }
            paint.setStyle(Paint.Style.FILL); paint.setColor(ink); paint.setTextAlign(Paint.Align.CENTER);
            paint.setTextSize(dp(13)); paint.setTypeface(Typeface.create("sans-serif-light", 0));
            canvas.drawCircle(x[hi], y[hi], dp(3), paint); canvas.drawText(degrees(high), x[hi], y[hi] - dp(10), paint);
            if (lo != hi) { canvas.drawCircle(x[lo], y[lo], dp(3), paint); canvas.drawText(degrees(low), x[lo], y[lo] + dp(20), paint); }
            paint.setColor(subtle); paint.setTextSize(dp(10));
            for (int i = 0; i < n; i += 6) {
                String stamp = hours.get(i).time;
                canvas.drawText(stamp.length() >= 13 ? stamp.substring(11, 13) : "—", x[i], getHeight() - dp(3), paint);
            }
        }
    }
    @Override public void onConfigurationChanged(Configuration config) { super.onConfigurationChanged(config); recreate(); }
    @Override protected void onDestroy() {
        ++generation; network.shutdownNow();
        HttpURLConnection connection = activeConnection; if (connection != null) connection.disconnect();
        super.onDestroy();
    }
    @Override public void finish() {
        super.finish();
        int id = getResources().getIdentifier("app_exit", "anim", getPackageName());
        if (id != 0) overridePendingTransition(0, id);
    }
}
