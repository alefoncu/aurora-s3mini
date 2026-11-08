package com.scratch.ios7launcher;

import android.content.Intent;
import android.net.Uri;
import android.provider.AlarmClock;
import android.provider.Settings;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * "Spotlight" answers for the search box: arithmetic, unit conversion, quick actions (alarm, timer, torch,
 * note) and shortcuts into Settings. Everything is computed locally; nothing needs the network except the
 * final "search the web" row.
 */
final class Smart {
    /** One extra row in the results. {@code glyph} is drawn on a coloured tile; {@code intent} or {@code special} is the action. */
    static final class Item {
        String glyph, title, sub;
        int color;
        Intent intent;
        String special;      // "copy:<text>", "torch", "note:<text>"
        Item(String glyph, int color, String title, String sub) { this.glyph = glyph; this.color = color; this.title = title; this.sub = sub; }
    }

    private Smart() { }

    // ---------------------------------------------------------------------------------------------
    // entry point

    static List<Item> answer(String raw) {
        List<Item> out = new ArrayList<>();
        String q = raw.trim();
        if (q.length() < 2) return out;
        Item it;
        if ((it = percent(q)) != null) out.add(it);
        else if ((it = convert(q)) != null) out.add(it);
        else if ((it = calc(q)) != null) out.add(it);
        String n = Fuzzy.norm(q);
        if ((it = alarm(n)) != null) out.add(it);
        if ((it = timer(n)) != null) out.add(it);
        if ((it = note(q, n)) != null) out.add(it);
        if (Fuzzy.score(n, "linterna") >= 60 || n.equals("torch") || n.equals("flash")) {
            it = new Item("☀", 0xFFF59E0B, "Linterna", "Encender o apagar"); it.special = "torch"; out.add(it);
        }
        out.addAll(settings(n));
        return out;
    }

    /** Last-resort row when nothing local matched. */
    static Item web(String q) {
        Item it = new Item("\u2315", 0xFF6366F1, "Buscar \u201c" + q + "\u201d en la web", "Navegador");
        it.intent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + Uri.encode(q)));
        return it;
    }

    // ---------------------------------------------------------------------------------------------
    // arithmetic

    private static Item calc(String q) {
        String s = q.replace('x', '*').replace('X', '*').replace('×', '*').replace('÷', '/').replace('−', '-').trim();
        if (s.endsWith("=")) s = s.substring(0, s.length() - 1).trim();
        if (!s.matches("[0-9.,()\\s+\\-*/^%]+")) return null;
        if (!s.matches(".*[0-9)]\\s*[+\\-*/^%]\\s*[0-9(].*")) return null;     // needs a binary operator between operands
        if (s.matches("[+0-9\\s]+")) return null;                                // looks like a phone number
        try {
            double v = new Parser(s.replace(',', '.')).parse();
            if (Double.isNaN(v) || Double.isInfinite(v)) return null;
            String r = fmt(v);
            Item it = new Item("=", 0xFF3B6BEA, r, q + "  ·  toca para copiar");
            it.special = "copy:" + r;
            return it;
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static Item percent(String q) {
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("^\\s*([0-9]+(?:[.,][0-9]+)?)\\s*%\\s*(?:de|of)\\s*([0-9]+(?:[.,][0-9]+)?)\\s*$", java.util.regex.Pattern.CASE_INSENSITIVE).matcher(q);
        if (!m.matches()) return null;
        double p = Double.parseDouble(m.group(1).replace(',', '.')), b = Double.parseDouble(m.group(2).replace(',', '.'));
        String r = fmt(p * b / 100.0);
        Item it = new Item("%", 0xFF3B6BEA, r, q + "  ·  toca para copiar");
        it.special = "copy:" + r;
        return it;
    }

    /** Recursive-descent: + - * / ^ and unary minus, parentheses, postfix %. */
    private static final class Parser {
        private final String s; private int i;
        Parser(String s) { this.s = s.replaceAll("\\s+", ""); }
        double parse() { double v = expr(); if (i != s.length()) throw new RuntimeException("junk"); return v; }
        private double expr() {
            double v = term();
            while (i < s.length() && (s.charAt(i) == '+' || s.charAt(i) == '-')) { char c = s.charAt(i++); double t = term(); v = c == '+' ? v + t : v - t; }
            return v;
        }
        private double term() {
            double v = power();
            while (i < s.length() && (s.charAt(i) == '*' || s.charAt(i) == '/')) { char c = s.charAt(i++); double t = power(); v = c == '*' ? v * t : v / t; }
            return v;
        }
        private double power() {
            double v = unary();
            if (i < s.length() && s.charAt(i) == '^') { i++; v = Math.pow(v, power()); }
            return v;
        }
        private double unary() {
            if (i < s.length() && s.charAt(i) == '-') { i++; return -unary(); }
            if (i < s.length() && s.charAt(i) == '+') { i++; return unary(); }
            return postfix();
        }
        private double postfix() {
            double v = atom();
            while (i < s.length() && s.charAt(i) == '%') { i++; v /= 100.0; }
            return v;
        }
        private double atom() {
            if (i < s.length() && s.charAt(i) == '(') { i++; double v = expr(); if (i >= s.length() || s.charAt(i) != ')') throw new RuntimeException("paren"); i++; return v; }
            int st = i;
            while (i < s.length() && (Character.isDigit(s.charAt(i)) || s.charAt(i) == '.')) i++;
            if (st == i) throw new RuntimeException("num");
            return Double.parseDouble(s.substring(st, i));
        }
    }

    static String fmt(double v) {
        if (v == Math.rint(v) && Math.abs(v) < 1e12) return String.format(Locale.US, "%d", (long) v);
        String r = String.format(Locale.US, "%.6g", v);
        if (r.contains("e")) return r.replace('.', ',');
        if (r.contains(".")) r = r.replaceAll("0+$", "").replaceAll("\\.$", "");
        return r.replace('.', ',');
    }

    // ---------------------------------------------------------------------------------------------
    // unit conversion

    /** dimension, factor to base unit (offset handled separately for temperature). */
    private static final Object[][] UNITS = {
        {"len", 0.001, "mm", "milimetro", "milimetros"},
        {"len", 0.01, "cm", "centimetro", "centimetros"},
        {"len", 1.0, "m", "metro", "metros"},
        {"len", 1000.0, "km", "kilometro", "kilometros"},
        {"len", 0.0254, "in", "pulgada", "pulgadas", "inch", "inches"},
        {"len", 0.3048, "ft", "pie", "pies", "feet", "foot"},
        {"len", 0.9144, "yd", "yarda", "yardas"},
        {"len", 1609.344, "mi", "milla", "millas", "mile", "miles"},
        {"mass", 0.001, "g", "gramo", "gramos"},
        {"mass", 1.0, "kg", "kilo", "kilos", "kilogramo", "kilogramos"},
        {"mass", 0.45359237, "lb", "libra", "libras", "pound", "pounds"},
        {"mass", 0.0283495, "oz", "onza", "onzas", "ounce", "ounces"},
        {"vol", 0.001, "ml", "mililitro", "mililitros"},
        {"vol", 1.0, "l", "litro", "litros"},
        {"vol", 3.785411784, "gal", "galon", "galones", "gallon"},
        {"speed", 1.0, "km/h", "kmh", "kph"},
        {"speed", 1.609344, "mph"},
        {"speed", 3.6, "m/s", "ms"},
        {"time", 1.0, "s", "seg", "segundo", "segundos"},
        {"time", 60.0, "min", "minuto", "minutos"},
        {"time", 3600.0, "h", "hora", "horas"},
        {"time", 86400.0, "d", "dia", "dias"},
        {"temp", 0.0, "c", "°c", "celsius", "grados"},
        {"temp", 1.0, "f", "°f", "fahrenheit"},
        {"temp", 2.0, "k", "kelvin"},
    };

    private static Object[] unit(String name) {
        String n = name.toLowerCase(Locale.ROOT).trim().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u");
        for (Object[] u : UNITS) for (int i = 2; i < u.length; i++) if (n.equals(u[i])) return u;
        return null;
    }

    private static Item convert(String q) {
        java.util.regex.Matcher m = java.util.regex.Pattern.compile(
            "^\\s*(-?[0-9]+(?:[.,][0-9]+)?)\\s*([^0-9\\s][^\\s]*?)\\s+(?:en|a|to|in|->|=)\\s+([^0-9\\s].*?)\\s*$", java.util.regex.Pattern.CASE_INSENSITIVE).matcher(q);
        if (!m.matches()) return null;
        double v = Double.parseDouble(m.group(1).replace(',', '.'));
        Object[] a = unit(m.group(2)), b = unit(m.group(3));
        if (a == null || b == null || !a[0].equals(b[0])) return null;
        double r;
        if ("temp".equals(a[0])) {
            int fa = (int) (double) (Double) a[1], fb = (int) (double) (Double) b[1];
            double c = fa == 0 ? v : fa == 1 ? (v - 32) * 5 / 9 : v - 273.15;
            r = fb == 0 ? c : fb == 1 ? c * 9 / 5 + 32 : c + 273.15;
        } else {
            r = v * (Double) a[1] / (Double) b[1];
        }
        String out = fmt(r) + " " + b[2];
        Item it = new Item("⇄", 0xFF14B8A6, out, fmt(v) + " " + a[2] + "  ·  toca para copiar");
        it.special = "copy:" + fmt(r);
        return it;
    }

    // ---------------------------------------------------------------------------------------------
    // actions

    private static Item alarm(String n) {
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("^(?:alarma|despiertame|despierta me|alarm)\\s*(?:a las|a la|para las|para la|at)?\\s*([0-9]{1,2})(?:[:.h ]([0-9]{2}))?\\s*(?:h|horas)?$").matcher(n);
        if (!m.matches()) return null;
        int h = Integer.parseInt(m.group(1)), mi = m.group(2) == null ? 0 : Integer.parseInt(m.group(2));
        if (h > 23 || mi > 59) return null;
        Item it = new Item("⏰", 0xFFEF4444, String.format(Locale.US, "Alarma a las %02d:%02d", h, mi), "Reloj");
        it.intent = new Intent(AlarmClock.ACTION_SET_ALARM).putExtra(AlarmClock.EXTRA_HOUR, h).putExtra(AlarmClock.EXTRA_MINUTES, mi)
                .setClassName("com.scratch.iosclock", "com.scratch.iosclock.IntentActivity");
        return it;
    }

    private static Item timer(String n) {
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("^(?:temporizador|timer|cuenta atras)\\s*(?:de)?\\s*([0-9]+)\\s*(min|minutos?|m|seg|segundos?|s|h|horas?)?$").matcher(n);
        if (!m.matches()) return null;
        int v = Integer.parseInt(m.group(1));
        String u = m.group(2) == null ? "min" : m.group(2);
        int sec = u.startsWith("h") ? v * 3600 : u.startsWith("s") ? v : v * 60;
        if (sec <= 0 || sec > 86400) return null;
        Item it = new Item("⏳", 0xFFF59E0B, "Temporizador de " + (sec >= 3600 ? (sec / 3600) + " h" : sec >= 60 ? (sec / 60) + " min" : sec + " s"), "Reloj");
        it.intent = new Intent(AlarmClock.ACTION_SET_TIMER).putExtra(AlarmClock.EXTRA_LENGTH, sec)
                .setClassName("com.scratch.iosclock", "com.scratch.iosclock.IntentActivity");
        return it;
    }

    private static Item note(String q, String n) {
        if (!(n.startsWith("nota ") || n.startsWith("note ") || n.startsWith("apunta "))) return null;
        String body = q.substring(q.indexOf(' ') + 1).trim();
        if (body.isEmpty()) return null;
        Item it = new Item("✎", 0xFFF59E0B, "Guardar nota", body);
        it.special = "note:" + body;
        return it;
    }

    // ---------------------------------------------------------------------------------------------
    // shortcuts into Settings

    private static final Object[][] SETTINGS = {
        {"Wi-Fi", Settings.ACTION_WIFI_SETTINGS, "wifi wi fi internet red redes"},
        {"Bluetooth", Settings.ACTION_BLUETOOTH_SETTINGS, "bluetooth"},
        {"Sonido y volumen", Settings.ACTION_SOUND_SETTINGS, "sonido volumen tono timbre"},
        {"Pantalla y brillo", Settings.ACTION_DISPLAY_SETTINGS, "pantalla brillo fondo"},
        {"Batería", Intent.ACTION_POWER_USAGE_SUMMARY, "bateria energia"},
        {"Almacenamiento", Settings.ACTION_INTERNAL_STORAGE_SETTINGS, "almacenamiento memoria espacio"},
        {"Aplicaciones", Settings.ACTION_APPLICATION_SETTINGS, "aplicaciones apps"},
        {"Ubicación", Settings.ACTION_LOCATION_SOURCE_SETTINGS, "ubicacion gps localizacion"},
        {"Fecha y hora", Settings.ACTION_DATE_SETTINGS, "fecha hora zona horaria"},
        {"Idioma y teclado", Settings.ACTION_LOCALE_SETTINGS, "idioma teclado"},
        {"Modo avión", Settings.ACTION_AIRPLANE_MODE_SETTINGS, "avion modo avion"},
        {"Accesibilidad", Settings.ACTION_ACCESSIBILITY_SETTINGS, "accesibilidad"},
        {"Datos móviles", Settings.ACTION_DATA_ROAMING_SETTINGS, "datos moviles roaming"},
    };

    private static List<Item> settings(String n) {
        List<Item> out = new ArrayList<>();
        if (n.length() < 3) return out;
        for (Object[] s : SETTINGS) {
            int best = 0;
            for (String kw : ((String) s[2]).split(" ")) best = Math.max(best, Fuzzy.score(n, kw));
            if (best >= 70 && out.size() < 2) {
                Item it = new Item("⚙", 0xFF64748B, (String) s[0], "Ajustes");
                it.intent = new Intent((String) s[1]);
                out.add(it);
            }
        }
        return out;
    }
}
