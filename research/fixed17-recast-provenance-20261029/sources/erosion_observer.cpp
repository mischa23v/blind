//
// Copyright (c) 2009-2010 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//

#include "Recast.h"
#include "RecastAlloc.h"
#include "RecastAssert.h"

#include <string.h> // for memcpy and memset

// ALTERED: isolated renamed erosion body, observer writes only; original license retained.
#include "observer.h"
bool provenanceErode(rcContext* context, const int erosionRadius, rcCompactHeightfield& compactHeightfield, ProvenanceTrace& trace)
{
	rcAssert(context != NULL);

	const int xSize = compactHeightfield.width;
	const int zSize = compactHeightfield.height;
	const int& zStride = xSize; // For readability

	rcScopedTimer timer(context, RC_TIMER_ERODE_AREA);

	unsigned char* distanceToBoundary = (unsigned char*)rcAlloc(sizeof(unsigned char) * compactHeightfield.spanCount,
	                                                            RC_ALLOC_TEMP);
	if (!distanceToBoundary)
	{
		context->log(RC_LOG_ERROR, "erodeWalkableArea: Out of memory 'dist' (%d).", compactHeightfield.spanCount);
		return false;
	}
	memset(distanceToBoundary, 0xff, sizeof(unsigned char) * compactHeightfield.spanCount);
	
	// Mark boundary cells.
	for (int z = 0; z < zSize; ++z)
	{
		for (int x = 0; x < xSize; ++x)
		{
			const rcCompactCell& cell = compactHeightfield.cells[x + z * zStride];
			for (int spanIndex = (int)cell.index, maxSpanIndex = (int)(cell.index + cell.count); spanIndex < maxSpanIndex; ++spanIndex)
			{
				if (compactHeightfield.areas[spanIndex] == RC_NULL_AREA)
				{
					distanceToBoundary[spanIndex] = 0;
					trace.boundary(spanIndex);
					continue;
				}
				const rcCompactSpan& span = compactHeightfield.spans[spanIndex];

				// Check that there is a non-null adjacent span in each of the 4 cardinal directions.
				int neighborCount = 0;
				for (int direction = 0; direction < 4; ++direction)
				{
					const int neighborConnection = rcGetCon(span, direction);
					if (neighborConnection == RC_NOT_CONNECTED)
					{
						break;
					}
					
					const int neighborX = x + rcGetDirOffsetX(direction);
					const int neighborZ = z + rcGetDirOffsetY(direction);
					const int neighborSpanIndex = (int)compactHeightfield.cells[neighborX + neighborZ * zStride].index + neighborConnection;
					
					if (compactHeightfield.areas[neighborSpanIndex] == RC_NULL_AREA)
					{
						break;
					}
					neighborCount++;
				}
				
				// At least one missing neighbour, so this is a boundary cell.
				if (neighborCount != 4)
				{
					distanceToBoundary[spanIndex] = 0;
					trace.boundary(spanIndex);
				}
			}
		}
	}
	
	unsigned char newDistance;
	
	// Pass 1
	for (int z = 0; z < zSize; ++z)
	{
		for (int x = 0; x < xSize; ++x)
		{
			const rcCompactCell& cell = compactHeightfield.cells[x + z * zStride];
			const int maxSpanIndex = (int)(cell.index + cell.count);
			for (int spanIndex = (int)cell.index; spanIndex < maxSpanIndex; ++spanIndex)
			{
				const rcCompactSpan& span = compactHeightfield.spans[spanIndex];

				if (rcGetCon(span, 0) != RC_NOT_CONNECTED)
				{
					// (-1,0)
					const int aX = x + rcGetDirOffsetX(0);
					const int aY = z + rcGetDirOffsetY(0);
					const int aIndex = (int)compactHeightfield.cells[aX + aY * xSize].index + rcGetCon(span, 0);
					const rcCompactSpan& aSpan = compactHeightfield.spans[aIndex];
					newDistance = (unsigned char)rcMin((int)distanceToBoundary[aIndex] + 2, 255);
					if (newDistance < distanceToBoundary[spanIndex])
					{
						distanceToBoundary[spanIndex] = newDistance;
						trace.improve(spanIndex, aIndex, newDistance);
					}

					// (-1,-1)
					if (rcGetCon(aSpan, 3) != RC_NOT_CONNECTED)
					{
						const int bX = aX + rcGetDirOffsetX(3);
						const int bY = aY + rcGetDirOffsetY(3);
						const int bIndex = (int)compactHeightfield.cells[bX + bY * xSize].index + rcGetCon(aSpan, 3);
						newDistance = (unsigned char)rcMin((int)distanceToBoundary[bIndex] + 3, 255);
						if (newDistance < distanceToBoundary[spanIndex])
						{
							distanceToBoundary[spanIndex] = newDistance;
							trace.improve(spanIndex, bIndex, newDistance);
						}
					}
				}
				if (rcGetCon(span, 3) != RC_NOT_CONNECTED)
				{
					// (0,-1)
					const int aX = x + rcGetDirOffsetX(3);
					const int aY = z + rcGetDirOffsetY(3);
					const int aIndex = (int)compactHeightfield.cells[aX + aY * xSize].index + rcGetCon(span, 3);
					const rcCompactSpan& aSpan = compactHeightfield.spans[aIndex];
					newDistance = (unsigned char)rcMin((int)distanceToBoundary[aIndex] + 2, 255);
					if (newDistance < distanceToBoundary[spanIndex])
					{
						distanceToBoundary[spanIndex] = newDistance;
						trace.improve(spanIndex, aIndex, newDistance);
					}

					// (1,-1)
					if (rcGetCon(aSpan, 2) != RC_NOT_CONNECTED)
					{
						const int bX = aX + rcGetDirOffsetX(2);
						const int bY = aY + rcGetDirOffsetY(2);
						const int bIndex = (int)compactHeightfield.cells[bX + bY * xSize].index + rcGetCon(aSpan, 2);
						newDistance = (unsigned char)rcMin((int)distanceToBoundary[bIndex] + 3, 255);
						if (newDistance < distanceToBoundary[spanIndex])
						{
							distanceToBoundary[spanIndex] = newDistance;
							trace.improve(spanIndex, bIndex, newDistance);
						}
					}
				}
			}
		}
	}

	// Pass 2
	for (int z = zSize - 1; z >= 0; --z)
	{
		for (int x = xSize - 1; x >= 0; --x)
		{
			const rcCompactCell& cell = compactHeightfield.cells[x + z * zStride];
			const int maxSpanIndex = (int)(cell.index + cell.count);
			for (int spanIndex = (int)cell.index; spanIndex < maxSpanIndex; ++spanIndex)
			{
				const rcCompactSpan& span = compactHeightfield.spans[spanIndex];

				if (rcGetCon(span, 2) != RC_NOT_CONNECTED)
				{
					// (1,0)
					const int aX = x + rcGetDirOffsetX(2);
					const int aY = z + rcGetDirOffsetY(2);
					const int aIndex = (int)compactHeightfield.cells[aX + aY * xSize].index + rcGetCon(span, 2);
					const rcCompactSpan& aSpan = compactHeightfield.spans[aIndex];
					newDistance = (unsigned char)rcMin((int)distanceToBoundary[aIndex] + 2, 255);
					if (newDistance < distanceToBoundary[spanIndex])
					{
						distanceToBoundary[spanIndex] = newDistance;
						trace.improve(spanIndex, aIndex, newDistance);
					}

					// (1,1)
					if (rcGetCon(aSpan, 1) != RC_NOT_CONNECTED)
					{
						const int bX = aX + rcGetDirOffsetX(1);
						const int bY = aY + rcGetDirOffsetY(1);
						const int bIndex = (int)compactHeightfield.cells[bX + bY * xSize].index + rcGetCon(aSpan, 1);
						newDistance = (unsigned char)rcMin((int)distanceToBoundary[bIndex] + 3, 255);
						if (newDistance < distanceToBoundary[spanIndex])
						{
							distanceToBoundary[spanIndex] = newDistance;
							trace.improve(spanIndex, bIndex, newDistance);
						}
					}
				}
				if (rcGetCon(span, 1) != RC_NOT_CONNECTED)
				{
					// (0,1)
					const int aX = x + rcGetDirOffsetX(1);
					const int aY = z + rcGetDirOffsetY(1);
					const int aIndex = (int)compactHeightfield.cells[aX + aY * xSize].index + rcGetCon(span, 1);
					const rcCompactSpan& aSpan = compactHeightfield.spans[aIndex];
					newDistance = (unsigned char)rcMin((int)distanceToBoundary[aIndex] + 2, 255);
					if (newDistance < distanceToBoundary[spanIndex])
					{
						distanceToBoundary[spanIndex] = newDistance;
						trace.improve(spanIndex, aIndex, newDistance);
					}

					// (-1,1)
					if (rcGetCon(aSpan, 0) != RC_NOT_CONNECTED)
					{
						const int bX = aX + rcGetDirOffsetX(0);
						const int bY = aY + rcGetDirOffsetY(0);
						const int bIndex = (int)compactHeightfield.cells[bX + bY * xSize].index + rcGetCon(aSpan, 0);
						newDistance = (unsigned char)rcMin((int)distanceToBoundary[bIndex] + 3, 255);
						if (newDistance < distanceToBoundary[spanIndex])
						{
							distanceToBoundary[spanIndex] = newDistance;
							trace.improve(spanIndex, bIndex, newDistance);
						}
					}
				}
			}
		}
	}

	const unsigned char minBoundaryDistance = (unsigned char)(erosionRadius * 2);
	for (int spanIndex = 0; spanIndex < compactHeightfield.spanCount; ++spanIndex)
	{
		if (distanceToBoundary[spanIndex] < minBoundaryDistance)
		{
			compactHeightfield.areas[spanIndex] = RC_NULL_AREA;
		}
	}

	memcpy(trace.distance, distanceToBoundary, compactHeightfield.spanCount);
	rcFree(distanceToBoundary);
	
	return true;
}
