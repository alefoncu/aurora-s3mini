import java.awt.*;
import java.awt.geom.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.File;

public class MakeIcon {
    public static void main(String[] a) throws Exception {
        int s = 192;
        BufferedImage im = new BufferedImage(s, s, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = im.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        Path2D sq = new Path2D.Float();
        double r = s / 2.0, n = 4.6;
        for (int i = 0; i <= 96; i++) {
            double t = 2 * Math.PI * i / 96, ct = Math.cos(t), st = Math.sin(t);
            double x = r + Math.signum(ct) * Math.pow(Math.abs(ct), 2 / n) * r;
            double y = r + Math.signum(st) * Math.pow(Math.abs(st), 2 / n) * r;
            if (i == 0) sq.moveTo(x, y); else sq.lineTo(x, y);
        }
        sq.closePath();
        g.setPaint(new GradientPaint(0, 0, new Color(0x8E8E93), 0, s, new Color(0x3A3A3C)));
        g.fill(sq);
        double u = s / 48.0;
        g.setColor(Color.WHITE);
        g.fill(new RoundRectangle2D.Double(8 * u, 15 * u, 32 * u, 21 * u, 8 * u, 8 * u));
        g.fill(new RoundRectangle2D.Double(17 * u, 11 * u, 14 * u, 6 * u, 4 * u, 4 * u));
        g.setColor(new Color(0x3A3A3C));
        g.fill(new Ellipse2D.Double(16.5 * u, 18 * u, 15 * u, 15 * u));
        g.setColor(Color.WHITE);
        g.fill(new Ellipse2D.Double(18.5 * u, 20 * u, 11 * u, 11 * u));
        g.setColor(new Color(0x3A3A3C));
        g.fill(new Ellipse2D.Double(21 * u, 22.5 * u, 6 * u, 6 * u));
        ImageIO.write(im, "png", new File(a[0]));
    }
}
