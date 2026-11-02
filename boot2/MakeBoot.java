import java.awt.*;
import java.awt.geom.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.File;

/** Minimal boot animation: a thin ring draws itself, then a comet orbits it until boot ends. */
public class MakeBoot {
    static final int W = 320, H = 320, CX = W / 2, CY = H / 2, R = 84;
    static final Color BG = new Color(0x14123A), LINE = new Color(0x33336B), TEXT = new Color(0xFFFFFF), ACCENT = new Color(0x6EA8FF), VIOLET = new Color(0x9F6BFF), PINK = new Color(0xF472B6);

    static Graphics2D g(BufferedImage im) {
        Graphics2D g = im.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
        g.setColor(BG);
        g.fillRect(0, 0, W, H);
        return g;
    }

    static void ring(Graphics2D g, Color c, float w, double start, double extent) {
        g.setColor(c);
        g.setStroke(new BasicStroke(w, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
        g.draw(new Arc2D.Double(CX - R, CY - R, 2 * R, 2 * R, start, extent, Arc2D.OPEN));
    }

    static double ease(double t) { return 1 - Math.pow(1 - t, 3); }

    static Color mix(Color a, Color b, double t) {
        return new Color((int) (a.getRed() + (b.getRed() - a.getRed()) * t),
                (int) (a.getGreen() + (b.getGreen() - a.getGreen()) * t),
                (int) (a.getBlue() + (b.getBlue() - a.getBlue()) * t));
    }

    public static void main(String[] a) throws Exception {
        File p0 = new File(a[0], "part0"), p1 = new File(a[0], "part1");
        p0.mkdirs(); p1.mkdirs();
        int n0 = 30, n1 = 24;
        // part0: faint ring fades in, bright arc draws a full turn, centre dot appears
        for (int i = 0; i < n0; i++) {
            BufferedImage im = new BufferedImage(W, H, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = g(im);
            double t = i / (double) (n0 - 1);
            double fade = Math.min(1, t * 4);
            ring(g, mix(BG, LINE, fade), 4f, 0, 360);
            double draw = ease(Math.min(1, t / 0.8));
            ring(g, mix(TEXT, LINE, Math.max(0, Math.min(1, (t - 0.8) / 0.2))), 4f, 90, -360 * draw);
            if (t > 0.6) {
                double d = ease((t - 0.6) / 0.4);
                g.setColor(mix(BG, PINK, d));
                double r = 9 * d;
                g.fill(new Ellipse2D.Double(CX - r, CY - r, 2 * r, 2 * r));
            }
            ImageIO.write(im, "png", new File(p0, String.format("%04d.png", i)));
        }
        // part1 (loop): static faint ring + accent comet orbiting, dot stays
        for (int i = 0; i < n1; i++) {
            BufferedImage im = new BufferedImage(W, H, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = g(im);
            ring(g, LINE, 4f, 0, 360);
            double head = 90 - 360.0 * i / n1;
            int seg = 24;
            for (int s = 0; s < seg; s++) {
                double k = s / (double) seg;
                ring(g, mix(BG, k < 0.5 ? mix(PINK, VIOLET, k * 2) : mix(VIOLET, ACCENT, (k - 0.5) * 2), 1 - k * 0.9), 4.2f, head + 6 * s, -6.5);
            }
            g.setColor(PINK);
            g.fill(new Ellipse2D.Double(CX - 9, CY - 9, 18, 18));
            ImageIO.write(im, "png", new File(p1, String.format("%04d.png", i)));
        }
        java.nio.file.Files.write(new File(a[0], "desc.txt").toPath(), "320 320 20\np 1 0 part0 #14123A\np 0 0 part1 #14123A\n".getBytes());
    }
}
