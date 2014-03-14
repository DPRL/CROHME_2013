##    DPRL CROHME 2013
##    Copyright (c) 2013-2014 Lei Hu, Kenny Davila, Francisco Alvaro, Richard Zanibbi
##
##    This file is part of DPRL CROHME 2013.
##
##    DPRL CROHME 2013 is free software: 
##    you can redistribute it and/or modify it under the terms of the GNU 
##    General Public License as published by the Free Software Foundation, 
##    either version 3 of the License, or (at your option) any later version.
##
##    DPRL CROHME 2013 is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with DPRL CROHME 2013.  
##    If not, see <http://www.gnu.org/licenses/>.
##
##    Contact:
##        - Lei Hu: lei.hu@rit.edu
##        - Kenny Davila: kxd7282@rit.edu
##        - Francisco Alvaro: falvaro@dsic.upv.es
##        - Richard Zanibbi: rlaz@cs.rit.edu 

#!/usr/bin/env python

"""convexhull.py

Calculate the convex hull of a set of n 2D-points in O(n log n) time.  
Taken from Berg et al., Computational Geometry, Springer-Verlag, 1997.

"""


import sys, string, random, math

######################################################################
# Helpers
######################################################################

def _myDet(p, q, r):
    """Calc. determinant of a special matrix with three 2D points.

    The sign, "-" or "+", determines the side, right or left,
    respectivly, on which the point r lies, when measured against
    a directed vector from p to q.
    """

    # We use Sarrus' Rule to calculate the determinant.
    # (could also use the Numeric package...)
    sum1 = q[0]*r[1] + p[0]*q[1] + r[0]*p[1]
    sum2 = q[0]*p[1] + r[0]*q[1] + p[0]*r[1]

    return sum1 - sum2


def _isRightTurn((p, q, r)):
    "Do the vectors pq:qr form a right turn, or not?"
    if p == q or q == r or p == r:
        print( p )
        print( q )
        print( r )
    assert p != q and q != r and p != r
            
    if _myDet(p, q, r) < 0:
	return 1
    else:
        return 0


def _isPointInPolygon(r, P):
    "Is point r inside a given polygon P?"

    # We assume the polygon is a list of points, listed clockwise!
    for i in xrange(len(P[:-1])):
        p, q = P[i], P[i+1]
        if not _isRightTurn((p, q, r)):
            return 0 # Out!        

    return 1 # It's within!


######################################################################
# Output
######################################################################

def saveAsSVG(P, H, boxSize, path):
    f = open(path, 'w')

    f.write('<?xml version="1.0" encoding="UTF-8" standalone="no"?>\r\n')
    f.write('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN"')
    f.write(' "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">\r\n')
    f.write('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"')
    f.write('   fill-rule="evenodd" height="10.0in" preserveAspectRatio="none" stroke-linecap="round"')
    f.write('   viewBox="0 0 ' + str(boxSize) + ' ' + str(boxSize) + '" width="10.0in">\r\n')

    f.write('<style type="text/css">\r\n')
    f.write('.pen0 { stroke: rgb(255,0,0); stroke-width: 1; stroke-linejoin: round; }\r\n')
    f.write('.pen1 { stroke: rgb(0,255,0); stroke-width: 1; stroke-linejoin: round; }\r\n')    
    f.write('</style>\r\n')

    f.write('<g>\r\n')

    #The polygon...
    f.write('<polyline class="pen0" fill="none" points="')
    for p in P:
        x, y = p
        f.write(str(x) + "," + str(y) + ' ')
    f.write('"/>')

    #The convex hull...
    #The polygon...
    f.write('<polyline class="pen1" fill="none" points="')
    for p in H:
        x, y = p
        f.write(str(x) + "," + str(y) + ' ')

    area = abs(ConvexArea(H))
    
    f.write('" area="' + str(area) + '"/>')

    #The convex hull...
    
    f.write('</g>\r\n')
    f.write('</svg>\r\n')    
    
    f.close()

######################################################################
# Public interface
######################################################################

def convexHull(P):
    "Calculate the convex hull of a set of points."

    # Get a local list copy of the points and sort them lexically.
    #print(P)
    points = map(None, P)
    points.sort()
    #print(points)

    # Build upper half of the hull.
    upper = [points[0], points[1]]
    for p in points[2:]:
        if not p in upper:
            upper.append(p)
            
	while len(upper) > 2 and not _isRightTurn(upper[-3:]):
	    del upper[-2]

    # Build lower half of the hull.
    points.reverse()
    lower = [points[0], points[1]]
    for p in points[2:]:
        if not p in lower:
            lower.append(p)
            
	while len(lower) > 2 and not _isRightTurn(lower[-3:]):
	    del lower[-2]

    # Remove duplicates.
    del lower[0]
    del lower[-1]

    # Concatenate both halfs and return.
    return tuple(upper + lower)

def convexArea(P):
    total = 0.0
    for i in range(len(P)):
        x1, y1 = P[i]
        x2, y2 = P[(i + 1) % len(P)]

        total += x1 * y2 - y1 * x2

    total *= 0.5

    return abs(total)

def convexPerimeter(P):
    total = 0.0
    for i in range(len(P)):
        x1, y1 = P[i]
        x2, y2 = P[(i + 1) % len(P)]

        total += math.sqrt( (x1 - x2) ** 2 + (y1 - y2) ** 2)

    return total

        
