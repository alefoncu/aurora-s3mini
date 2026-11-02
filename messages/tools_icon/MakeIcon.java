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
        g.setPaint(new GradientPaint(0, 0, new Color(0x60A5FA), 0, s, new Color(0x2563EB)));
        g.fill(sq);
        double u = s / 48.0;
        g.setColor(Color.WHITE);
        g.setStroke(new BasicStroke((float) (2.9 * u), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
        g.draw(new RoundRectangle2D.Double(9 * u, 11 * u, 30 * u, 21 * u, 16 * u, 16 * u));
        Path2D t = new Path2D.Double();
        t.moveTo(16 * u, 32 * u); t.lineTo(15 * u, 39 * u); t.lineTo(23 * u, 32 * u);
        g.draw(t);
        ImageIO.write(im, "png", new File(a[0]));
    }
}
