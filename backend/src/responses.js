export function ok(res, data = {}, message = 'Operation completed', status = 200) {
  return res.status(status).json({ success: true, message, data });
}

export function fail(res, status, message, details) {
  const body = { success: false, message, data: {} };
  if (details) body.details = details;
  return res.status(status).json(body);
}
