// Diagnostic only: observe the documented upstream isOverPoly output. It does
// NOT modify the route, admission policy, geometry, profile or projected point.
extern "C" int bn_probe_association(void* handle, const float* position,
                                      const float* extents, float* projected, int* over) {
    if (!handle || !finite3(position) || !finite3(extents) || !projected || !over) return 0;
    *over=0; BNHandle* h=static_cast<BNHandle*>(handle); dtQueryFilter filter;
    filter.setIncludeFlags(1); filter.setExcludeFlags(0);
    dtPolyRef ref=0; bool inside=false;
    const dtStatus status=h->query->findNearestPoly(position,extents,&filter,&ref,projected,&inside);
    if (dtStatusFailed(status) || !ref) return 0;
    *over=inside ? 1 : 0; return 1;
}
