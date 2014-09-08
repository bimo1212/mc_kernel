#!/usr/bin/env python
import matplotlib.pyplot as plt
import numpy as np
#from mpl_toolkits.basemap import Basemap
#from obspy.imaging.beachball import Beach

strike = 90.
dip = 90.
rake = 0.
rupture_velo = 0.9
rupture_len = 1000
npoints = 10
slip = 10.
dep = 50
vs = 5.

dt = 0.1
nts = 3

lonstart = 0.

area = rupture_len * dep * 2 / npoints

equator_len = 2 * np.pi * 6371

lat = np.zeros(npoints)
lon = np.linspace(lonstart, lonstart + rupture_len / equator_len * 360., npoints)
tinit = np.linspace(0., rupture_len, npoints) / (rupture_velo * vs)

f = open('strike_slip_eq.srf', 'w')
f.write('POINTS %d\n' % (npoints,))

for i in np.arange(npoints):
    #lon, lat, dep, stk, dip, area, tinit, dt
    f.write('%11.5f %11.5f %11.5f %11.5f %11.5f %11.5f %11.5f %11.5f\n' %
        (lon[i], lat[i], dep, strike, dip, area, tinit[i], dt))

    # rake, slip1, nt1, slip2, nt2, slip3, nt3
    f.write('%11.5f %11.5f %5d %11.5f %5d %11.5f %5d\n' %
        (rake, slip, nts, 0., 0, 0., 0))

    f.write('%11.5f %11.5f %11.5f\n' % (0., 1., 0.))

f.close()

#m = Basemap(projection='cyl', lon_0=0, lat_0=0, resolution='c')
#
#m.drawcoastlines()
#m.fillcontinents()
#m.drawparallels(np.arange(-90., 120., 30.))
#m.drawmeridians(np.arange(0., 420., 60.))
#m.drawmapboundary()
#
#focmecs = [strike, dip, rake]
#
#ax = plt.gca()
#for i in np.arange(npoints):
#    x, y = m(lon[i], lat[i])
#    b = Beach(focmecs, xy=(x, y), width=10, linewidth=1, alpha=0.85)
#    b.set_zorder(10)
#    ax.add_collection(b)
#plt.show()
