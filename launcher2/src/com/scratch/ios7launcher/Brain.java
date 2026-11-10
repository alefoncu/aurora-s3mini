package com.scratch.ios7launcher;

import android.content.Intent;

import java.text.SimpleDateFormat;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Natural-language understanding for the search box, entirely on the device: reminders and events with
 * spoken dates ("evento dentista mañana a las 18"), world clocks, countdowns, date questions, and
 * brightness / volume / ringer commands. Input is already normalised with {@link Fuzzy#norm}.
 */
final class Brain {
    private Brain() { }

    private static final String[] DAYS = {"domingo", "lunes", "martes", "miercoles", "jueves", "viernes", "sabado"};   // Calendar.SUNDAY == 1
    private static final Locale ES = new Locale("es", "ES");

    static void answer(String q, String n, List<Smart.Item> out) {
        Smart.Item it;
        if ((it = routine(n)) != null) out.add(it);
        if ((it = event(q, n)) != null) out.add(it);
        if ((it = worldClock(n)) != null) out.add(it);
        if ((it = countdown(n)) != null) out.add(it);
        if ((it = dateQuestion(n)) != null) out.add(it);
        if ((it = level(n, "brillo", "bright", "☀", 0xFFF59E0B, "Brillo")) != null) out.add(it);
        if ((it = level(n, "volumen", "vol", "♪", 0xFFEC4899, "Volumen multimedia")) != null) out.add(it);
        if ((it = ringer(n)) != null) out.add(it);
    }

    // ---- when -------------------------------------------------------------------------------------

    /** Parses "hoy / mañana / pasado mañana / lunes ... / en 2 horas" plus "a las 18[:30]". Null when there is no date or time word. */
    static Calendar when(String n) {
        Calendar c = Calendar.getInstance();
        c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0);
        boolean any = false;
        Matcher in = Pattern.compile("(?<![a-z])en ([0-9]{1,3}) (minutos?|horas?|dias?)(?![a-z])").matcher(n);
        if (in.find()) {
            int v = Integer.parseInt(in.group(1));
            String u = in.group(2);
            c.add(u.startsWith("min") ? Calendar.MINUTE : u.startsWith("hora") ? Calendar.HOUR_OF_DAY : Calendar.DAY_OF_YEAR, v);
            return c;
        }
        if (n.contains("pasado manana")) { c.add(Calendar.DAY_OF_YEAR, 2); any = true; }
        else if (n.matches(".*\\bmanana\\b.*")) { c.add(Calendar.DAY_OF_YEAR, 1); any = true; }
        else if (n.matches(".*\\bhoy\\b.*")) any = true;
        else {
            for (int d = 0; d < 7; d++) {
                if (n.matches(".*\\b" + DAYS[d] + "\\b.*")) {
                    int diff = (d + 1) - c.get(Calendar.DAY_OF_WEEK);
                    if (diff <= 0) diff += 7;
                    c.add(Calendar.DAY_OF_YEAR, diff); any = true; break;
                }
            }
        }
        boolean hasTime = false;
        Matcher tm = Pattern.compile("(?<![a-z])(?:a las|a la|sobre las) ([0-9]{1,2})(?: ([0-9]{2}))?(?: de la (tarde|noche|manana))?(?![a-z0-9])").matcher(n);
        if (tm.find()) {
            int h = Integer.parseInt(tm.group(1)), mi = tm.group(2) == null ? 0 : Integer.parseInt(tm.group(2));
            String part = tm.group(3);
            if (part != null && !part.equals("manana") && h < 12) h += 12;
            if (h > 23 || mi > 59) return null;
            c.set(Calendar.HOUR_OF_DAY, h); c.set(Calendar.MINUTE, mi);
            hasTime = true; any = true;
        }
        if (!any) return null;
        if (!hasTime) { c.set(Calendar.HOUR_OF_DAY, 9); c.set(Calendar.MINUTE, 0); }
        if (c.getTimeInMillis() < System.currentTimeMillis() - 60000 && !n.matches(".*\\b(hoy)\\b.*") ) c.add(Calendar.DAY_OF_YEAR, 1);
        return c;
    }

    private static Smart.Item event(String q, String n) {
        Matcher m = Pattern.compile("^(evento|cita|reunion|recuerdame|recordatorio|recordarme|avisame|apunta evento|agenda) (?:que |de |para )?(.+)$").matcher(n);
        if (!m.matches()) return null;
        String body = m.group(2);
        boolean reminder = m.group(1).startsWith("recuerdame") || m.group(1).startsWith("recordatorio") || m.group(1).startsWith("recordarme") || m.group(1).startsWith("avisame");
        Calendar c = when(body);
        if (c == null) return null;
        String title = body
                .replaceAll("(?<![a-z])en [0-9]{1,3} (minutos?|horas?|dias?)(?![a-z])", " ")
                .replaceAll("(?<![a-z])(pasado manana|manana|hoy|lunes|martes|miercoles|jueves|viernes|sabado|domingo)(?![a-z])", " ")
                .replaceAll("(?<![a-z])(?:a las|a la|sobre las) [0-9]{1,2}(?: [0-9]{2})?(?: de la (?:tarde|noche|manana))?(?![a-z0-9])", " ")
                .replaceAll("\\s+", " ").trim();
        if (title.isEmpty()) title = "Evento";
        title = Character.toUpperCase(title.charAt(0)) + title.substring(1);
        String when = new SimpleDateFormat("EEE d MMM, HH:mm", ES).format(c.getTime());
        if (reminder) {
            Smart.Item r = new Smart.Item("\u23f0", 0xFFF59E0B, "Recordarte: " + title, when);
            r.special = "remind:" + c.getTimeInMillis() + "|" + title;
            return r;
        }
        Smart.Item it = new Smart.Item("▦", 0xFFEF4444, "Crear evento: " + title, when);
        it.special = "event:" + c.getTimeInMillis() + "|" + title;
        return it;
    }

    // ---- world clock ------------------------------------------------------------------------------

    private static final String[][] ZONES = {
        {"tokio", "Asia/Tokyo", "Tokio"}, {"londres", "Europe/London", "Londres"}, {"paris", "Europe/Paris", "París"},
        {"berlin", "Europe/Berlin", "Berlín"}, {"roma", "Europe/Rome", "Roma"}, {"lisboa", "Europe/Lisbon", "Lisboa"},
        {"moscu", "Europe/Moscow", "Moscú"}, {"nueva york", "America/New_York", "Nueva York"}, {"chicago", "America/Chicago", "Chicago"},
        {"los angeles", "America/Los_Angeles", "Los Ángeles"}, {"san francisco", "America/Los_Angeles", "San Francisco"},
        {"mexico", "America/Mexico_City", "México DF"}, {"bogota", "America/Bogota", "Bogotá"}, {"lima", "America/Lima", "Lima"},
        {"santiago", "America/Santiago", "Santiago"}, {"buenos aires", "America/Argentina/Buenos_Aires", "Buenos Aires"},
        {"sao paulo", "America/Sao_Paulo", "São Paulo"}, {"sidney", "Australia/Sydney", "Sídney"}, {"pekin", "Asia/Shanghai", "Pekín"},
        {"shanghai", "Asia/Shanghai", "Shanghái"}, {"seul", "Asia/Seoul", "Seúl"}, {"singapur", "Asia/Singapore", "Singapur"},
        {"dubai", "Asia/Dubai", "Dubái"}, {"delhi", "Asia/Kolkata", "Delhi"}, {"el cairo", "Africa/Cairo", "El Cairo"},
        {"canarias", "Atlantic/Canary", "Canarias"}, {"madrid", "Europe/Madrid", "Madrid"}, {"miami", "America/New_York", "Miami"},
    };

    private static Smart.Item worldClock(String n) {
        Matcher m = Pattern.compile("^(?:que )?hora (?:es )?en (.+)$").matcher(n);
        if (!m.matches()) return null;
        String city = m.group(1).trim();
        for (String[] z : ZONES) {
            if (z[0].equals(city) || (city.length() >= 4 && z[0].startsWith(city))) {
                TimeZone tz = TimeZone.getTimeZone(z[1]);
                Date now = new Date();
                SimpleDateFormat f = new SimpleDateFormat("HH:mm", ES); f.setTimeZone(tz);
                int diffMin = (tz.getOffset(now.getTime()) - TimeZone.getDefault().getOffset(now.getTime())) / 60000;
                String diff = diffMin == 0 ? "misma hora que aquí" : (diffMin > 0 ? "+" : "−") + Math.abs(diffMin) / 60 + (Math.abs(diffMin) % 60 != 0 ? ":" + String.format(Locale.US, "%02d", Math.abs(diffMin) % 60) : "") + " h respecto a aquí";
                SimpleDateFormat day = new SimpleDateFormat("EEEE d", ES); day.setTimeZone(tz);
                Smart.Item it = new Smart.Item("◷", 0xFF6366F1, f.format(now) + " en " + z[2], day.format(now) + " · " + diff);
                it.special = "copy:" + f.format(now);
                return it;
            }
        }
        return null;
    }

    // ---- countdowns and date questions ------------------------------------------------------------

    private static Smart.Item countdown(String n) {
        Matcher m = Pattern.compile("^(?:cuanto falta para|dias para|dias hasta|cuantos dias faltan para|faltan para) (?:el |la |las )?(.+)$").matcher(n);
        if (!m.matches()) return null;
        String w = m.group(1).trim();
        int month = -1, day = -1; String label = null;
        if (w.startsWith("navidad")) { month = Calendar.DECEMBER; day = 25; label = "Navidad"; }
        else if (w.startsWith("nochebuena")) { month = Calendar.DECEMBER; day = 24; label = "Nochebuena"; }
        else if (w.startsWith("nochevieja") || w.startsWith("fin de ano") || w.startsWith("ano nuevo")) { month = Calendar.DECEMBER; day = 31; label = "Nochevieja"; }
        else if (w.startsWith("reyes")) { month = Calendar.JANUARY; day = 6; label = "Reyes"; }
        else if (w.startsWith("san valentin")) { month = Calendar.FEBRUARY; day = 14; label = "San Valentín"; }
        else if (w.startsWith("verano")) { month = Calendar.JUNE; day = 21; label = "el verano"; }
        else {
            Matcher d = Pattern.compile("^([0-9]{1,2}) de ([a-z]+)$").matcher(w);
            String[] ms = {"enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"};
            if (d.matches()) for (int i = 0; i < 12; i++) if (ms[i].startsWith(d.group(2)) && d.group(2).length() >= 3) { month = i; day = Integer.parseInt(d.group(1)); label = d.group(1) + " de " + ms[i]; }
        }
        if (month < 0 || day < 1 || day > 31) return null;
        Calendar today = Calendar.getInstance();
        Calendar t = Calendar.getInstance();
        t.set(today.get(Calendar.YEAR), month, day, 0, 0, 0);
        Calendar td = (Calendar) today.clone(); td.set(Calendar.HOUR_OF_DAY, 0); td.set(Calendar.MINUTE, 0); td.set(Calendar.SECOND, 0); td.set(Calendar.MILLISECOND, 0);
        t.set(Calendar.MILLISECOND, 0);
        if (t.before(td)) t.add(Calendar.YEAR, 1);
        long days = Math.round((t.getTimeInMillis() - td.getTimeInMillis()) / 86400000.0);
        String title = days == 0 ? "Es hoy" : days == 1 ? "Falta 1 día" : "Faltan " + days + " días";
        Smart.Item it = new Smart.Item("⌛", 0xFF8B5CF6, title, "para " + label + " · " + (days >= 14 ? (days / 7) + " semanas" : "tiempo justo"));
        it.special = "copy:" + days;
        return it;
    }

    private static Smart.Item dateQuestion(String n) {
        if (n.equals("que dia es hoy") || n.equals("que dia es") || n.equals("fecha") || n.equals("hoy")) {
            Calendar c = Calendar.getInstance();
            String s = new SimpleDateFormat("EEEE d 'de' MMMM 'de' yyyy", ES).format(c.getTime());
            Smart.Item it = new Smart.Item("▦", 0xFF3B6BEA, Character.toUpperCase(s.charAt(0)) + s.substring(1),
                    "Semana " + c.get(Calendar.WEEK_OF_YEAR) + " · día " + c.get(Calendar.DAY_OF_YEAR) + " del año");
            it.special = "copy:" + s;
            return it;
        }
        if (n.equals("que hora es") || n.equals("hora")) {
            String s = new SimpleDateFormat("HH:mm", ES).format(new Date());
            Smart.Item it = new Smart.Item("◷", 0xFF3B6BEA, s, TimeZone.getDefault().getID().replace('_', ' ')); it.special = "copy:" + s; return it;
        }
        return null;
    }

    // ---- device controls ---------------------------------------------------------------------------

    private static Smart.Item level(String n, String word, String key, String glyph, int color, String title) {
        Matcher m = Pattern.compile("^" + word + " (?:al |a )?([0-9]{1,3})(?: ?%| por ciento)?$").matcher(n);
        if (!m.matches()) return null;
        int v = Math.max(0, Math.min(100, Integer.parseInt(m.group(1))));
        Smart.Item it = new Smart.Item(glyph, color, title + " al " + v + " %", "Ajustar ahora");
        it.special = key + ":" + v;
        return it;
    }

    private static Smart.Item ringer(String n) {
        if (n.equals("silencio") || n.equals("silenciar") || n.equals("vibrar") || n.equals("modo vibracion") || n.equals("modo silencio")) {
            Smart.Item it = new Smart.Item("⊘", 0xFF64748B, "Modo vibración", "Silenciar el timbre"); it.special = "ring:vib"; return it;
        }
        if (n.equals("sonido") || n.equals("timbre") || n.equals("quitar silencio") || n.equals("modo normal")) {
            Smart.Item it = new Smart.Item("♪", 0xFF22C55E, "Timbre activado", "Volver al sonido normal"); it.special = "ring:normal"; return it;
        }
        return null;
    }

    // ---- currencies ---------------------------------------------------------------------------------

    private static final String[][] CUR = {
        {"eur", "EUR"}, {"euro", "EUR"}, {"euros", "EUR"}, {"usd", "USD"}, {"dolar", "USD"}, {"dolares", "USD"}, {"gbp", "GBP"}, {"libra", "GBP"}, {"libras", "GBP"},
        {"jpy", "JPY"}, {"yen", "JPY"}, {"yenes", "JPY"}, {"chf", "CHF"}, {"franco", "CHF"}, {"francos", "CHF"}, {"cad", "CAD"}, {"aud", "AUD"}, {"cny", "CNY"},
        {"yuan", "CNY"}, {"yuanes", "CNY"}, {"brl", "BRL"}, {"real", "BRL"}, {"reales", "BRL"}, {"mxn", "MXN"}, {"peso", "MXN"}, {"pesos", "MXN"}, {"inr", "INR"},
        {"rupia", "INR"}, {"rupias", "INR"}, {"krw", "KRW"}, {"won", "KRW"}, {"sek", "SEK"}, {"nok", "NOK"}, {"pln", "PLN"}, {"zloty", "PLN"}, {"try", "TRY"}, {"lira", "TRY"},
    };

    private static String cur(String w) { for (String[] c : CUR) if (c[0].equals(w)) return c[1]; return null; }

    /** "20 dolares en euros" / "100 eur a gbp" -> {amount, FROM, TO}; null when it is not a currency question. */
    static String[] parseFx(String n) {
        Matcher m = Pattern.compile("^([0-9]+(?: [0-9]+)?) ?([a-z]+) (?:en|a|to|in) ([a-z]+)$").matcher(n);
        if (!m.matches()) return null;
        String from = cur(m.group(2)), to = cur(m.group(3));
        if (from == null || to == null || from.equals(to)) return null;
        return new String[]{m.group(1).replace(' ', '.'), from, to};
    }

    // ---- routines ---------------------------------------------------------------------------------------

    private static Smart.Item routine(String n) {
        Matcher m = Pattern.compile("^(?:resumen diario|resumen de la manana|resumen matinal|briefing)(?: a las| a la| de las)? ?([0-9]{1,2})?(?: ([0-9]{2}))?$").matcher(n);
        if (m.matches()) {
            int h = m.group(1) == null ? 7 : Integer.parseInt(m.group(1)), mi = m.group(2) == null ? (m.group(1) == null ? 30 : 0) : Integer.parseInt(m.group(2));
            if (h > 23 || mi > 59) return null;
            Smart.Item it = new Smart.Item("\u2600", 0xFFF59E0B, String.format(Locale.US, "Resumen diario a las %02d:%02d", h, mi), "Tiempo, alarma y eventos del día en una notificación");
            it.special = "routine:brief:" + h + ":" + mi;
            return it;
        }
        m = Pattern.compile("^(?:silencio nocturno|no molestar|modo noche automatico|horario de silencio)(?: de| desde)? ?([0-9]{1,2}) (?:a|hasta)(?: las)? ([0-9]{1,2})$").matcher(n);
        if (m.matches()) {
            int f = Integer.parseInt(m.group(1)), t = Integer.parseInt(m.group(2));
            if (f > 23 || t > 23 || f == t) return null;
            Smart.Item it = new Smart.Item("\u263e", 0xFF6366F1, String.format(Locale.US, "Silencio nocturno %02d:00 \u2192 %02d:00", f, t), "El timbre pasa a vibración en ese horario");
            it.special = "routine:quiet:" + f + ":" + t;
            return it;
        }
        if (n.equals("quitar resumen diario") || n.equals("sin resumen diario") || n.equals("desactivar resumen diario")) {
            Smart.Item it = new Smart.Item("\u2715", 0xFF94A3B8, "Desactivar el resumen diario", "Rutinas"); it.special = "routine:brief:off"; return it;
        }
        if (n.equals("quitar silencio nocturno") || n.equals("sin silencio nocturno") || n.equals("desactivar silencio nocturno")) {
            Smart.Item it = new Smart.Item("\u2715", 0xFF94A3B8, "Desactivar el silencio nocturno", "Rutinas"); it.special = "routine:quiet:off"; return it;
        }
        if (n.equals("silencio en reuniones") || n.equals("silenciar en reuniones") || n.equals("activar silencio en reuniones")) {
            Smart.Item it = new Smart.Item("\u263e", 0xFF6366F1, "Silencio automático en reuniones", "Vibración mientras haya un evento en el calendario"); it.special = "routine:meet:on"; return it;
        }
        if (n.equals("quitar silencio en reuniones") || n.equals("sin silencio en reuniones")) {
            Smart.Item it = new Smart.Item("\u2715", 0xFF94A3B8, "Desactivar el silencio en reuniones", "Rutinas"); it.special = "routine:meet:off"; return it;
        }
        if (n.equals("rutinas") || n.equals("automatizaciones")) {
            Smart.Item it = new Smart.Item("\u2699", 0xFF8B5CF6, "Probar el resumen diario ahora", "Muestra la notificación como llegará por la mañana"); it.special = "routine:brief:now"; return it;
        }
        if (n.equals("probar revision de manana") || n.equals("revisar manana")) {
            Smart.Item it = new Smart.Item("\u23f0", 0xFFEF4444, "Revisar mañana ahora", "Cita temprana sin alarma: te propongo ponerla"); it.special = "routine:tomorrow"; return it;
        }
        if (n.equals("probar consejo al salir") || n.equals("consejo al salir de casa")) {
            Smart.Item it = new Smart.Item("\u2602", 0xFF38BDF8, "Probar el consejo al salir de casa", "Según el tiempo de hoy"); it.special = "routine:leave"; return it;
        }
        return null;
    }
}
