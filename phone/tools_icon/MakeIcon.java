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
        g.setPaint(new GradientPaint(0, 0, new Color(0x34D399), 0, s, new Color(0x059669)));
        g.fill(sq);
        double u = s / 48.0;
        g.setColor(Color.WHITE);
        g.setStroke(new BasicStroke((float) (2.9 * u), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
        Path2D h = new Path2D.Double();
        h.moveTo(14*u*1.0, 10*u); h.lineTo(19.5*u, 10*u); h.lineTo(21.5*u, 17*u); h.lineTo(18*u, 19.5*u);
        h.curveTo(20*u, 24*u, 24*u, 28*u, 28.5*u, 30*u); h.lineTo(31*u, 26.5*u); h.lineTo(38*u, 28.5*u); h.lineTo(38*u, 34*u);
        h.curveTo(38*u, 36*u, 36.5*u, 37.5*u, 34.5*u, 37.5*u); h.curveTo(22*u, 37*u, 11*u, 26*u, 10.5*u, 13.5*u);
        h.curveTo(10.5*u, 11.5*u, 12*u, 10*u, 14*u, 10*u); h.closePath();
        g.draw(h);
        ImageIO.write(im, "png", new File(a[0]));
    }
}
