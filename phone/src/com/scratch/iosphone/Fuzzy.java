package com.scratch.iosphone;

import java.text.Normalizer;
import java.util.HashMap;
import java.util.Map;

/**
 * Forgiving text matching for the search boxes: ignores case and accents ("camara" finds "Cámara"),
 * matches every typed word independently, prefers word starts and tolerates one or two typos.
 * Keep this file identical in the launcher, Phone and Contacts apps (only the package line changes).
 */
final class Fuzzy {
    private Fuzzy() { }

    /** Lower-case, accents removed, anything that is not a letter or digit becomes a single space. */
    static String norm(String s) {
        if (s == null) return "";
        String n = Normalizer.normalize(s, Normalizer.Form.NFD);
        StringBuilder sb = new StringBuilder(n.length());
        boolean space = true;
        for (int i = 0; i < n.length(); i++) {
            char c = Character.toLowerCase(n.charAt(i));
            if (Character.getType(c) == Character.NON_SPACING_MARK) continue;
            if (Character.isLetterOrDigit(c)) { sb.append(c); space = false; }
            else if (!space) { sb.append(' '); space = true; }
        }
        int len = sb.length();
        if (len > 0 && sb.charAt(len - 1) == ' ') sb.setLength(len - 1);
        return sb.toString();
    }

    /** 0 = no match, higher = better. Both arguments must already be normalised. */
    static int score(String query, String text) {
        if (query.isEmpty() || text.isEmpty()) return 0;
        String[] qs = query.split(" "), ws = text.split(" ");
        int total = 0;
        for (String q : qs) {
            int best = 0;
            for (String w : ws) best = Math.max(best, word(q, w));
            if (best == 0) return 0;
            total += best;
        }
        int s = total / qs.length;
        if (qs.length == 1 && query.length() >= 2 && ws.length >= 2 && initials(ws).startsWith(query)) s = Math.max(s, 66);
        if (text.startsWith(query)) s += 25;            // the whole name starts with what was typed
        else if (text.contains(query)) s += 8;
        return s;
    }

    /** Rough Spanish phonetics, so spelling mistakes that sound the same ("telefono"/"teléfono", "bateria"/"vateria", "jeneral"/"general") collide. */
    static String phon(String w) {
        String s = w.replace("ch", "#").replace("ll", "y").replace("qu", "k").replace("ph", "f")
                .replace("gue", "ge").replace("gui", "gi").replace("ge", "je").replace("gi", "ji")
                .replace("ce", "se").replace("ci", "si").replace("z", "s").replace("c", "k")
                .replace("v", "b").replace("w", "u").replace("y", "i").replace("h", "");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) if (i == 0 || s.charAt(i) != s.charAt(i - 1)) sb.append(s.charAt(i));
        return sb.toString();
    }

    /** True when the characters of q appear in w in order, starting with its first character. */
    private static boolean subsequence(String q, String w) {
        if (q.length() < 3 || w.isEmpty() || q.charAt(0) != w.charAt(0)) return false;
        int j = 0;
        for (int i = 0; i < w.length() && j < q.length(); i++) if (w.charAt(i) == q.charAt(j)) j++;
        return j == q.length();
    }

    private static int word(String q, String w) {
        int a = plain(q, w);
        if (a >= 85) return a;
        int b = 0;
        if (q.length() >= 2) {
            String pq = phon(q), pw = phon(w);
            if (pw.equals(pq)) b = 72;
            else if (pw.startsWith(pq) && pq.length() >= 2) b = 62;
            else if (pq.length() >= 4 && pq.charAt(0) == pw.charAt(0) && distance(pq, pw.length() > pq.length() ? pw.substring(0, pq.length()) : pw) <= (pq.length() >= 7 ? 2 : 1)) b = 36;
        }
        int c = subsequence(q, w) ? 14 : 0;
        return Math.max(a, Math.max(b, c));
    }

    private static int plain(String q, String w) {
        if (w.equals(q)) return 100;
        if (w.startsWith(q)) return 85 - Math.min(20, w.length() - q.length());
        if (q.length() >= 3 && w.contains(q)) return 45;
        if (q.length() >= 4) {                          // typos: compare against the same-length prefix of the word
            int allowed = q.length() >= 7 ? 2 : 1;
            String head = w.length() > q.length() ? w.substring(0, q.length()) : w;
            int d = distance(q, head);
            if (d <= allowed) return 40 - d * 8;
            d = distance(q, w);
            if (d <= allowed) return 35 - d * 8;
        }
        return 0;
    }

    private static String initials(String[] ws) {
        StringBuilder sb = new StringBuilder();
        for (String w : ws) if (!w.isEmpty()) sb.append(w.charAt(0));
        return sb.toString();
    }

    /** Levenshtein distance with transposition, for short words. */
    static int distance(String a, String b) {
        int n = a.length(), m = b.length();
        if (Math.abs(n - m) > 3) return 99;
        int[][] d = new int[n + 1][m + 1];
        for (int i = 0; i <= n; i++) d[i][0] = i;
        for (int j = 0; j <= m; j++) d[0][j] = j;
        for (int i = 1; i <= n; i++) {
            for (int j = 1; j <= m; j++) {
                int cost = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                d[i][j] = Math.min(Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost);
                if (i > 1 && j > 1 && a.charAt(i - 1) == b.charAt(j - 2) && a.charAt(i - 2) == b.charAt(j - 1)) d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
            }
        }
        return d[n][m];
    }
}
