/**
 * @description Provides utility methods for deployment date calculations, cron formatting, hashing, and JSON key patching.
 * @author develop@mpdigitals.com
 */
public class DeployUtils {

    /**
     * @description Calculates the start datetime for retrieving deployments based on frequency settings.
     * @param cfg DeploySetup__c custom setting record.
     * @param ref Reference datetime (usually System.now()).
     * @return Datetime calculated by subtracting the configured time unit.
     */
    public static Datetime calculateFromTime(DeploySetup__c cfg, Datetime ref) {
        String u = cfg.FrequencyUnit__c != null ? cfg.FrequencyUnit__c.toLowerCase() : '';
        Integer n = Integer.valueOf(cfg.FrequencyValue__c);
        if (u == 'days') {
            return ref.addDays(-n);
        }
        if (u == 'months') {
            return ref.addMonths(-n);
        }
        if (u == 'hours') {
            return ref.addHours(-n);
        }
        if (u == 'minutes') {
            return ref.addMinutes(-n);
        }
        return DeployConstants.EPOCH;
    }

    /**
     * @description Generates a CRON expression from a datetime to schedule a job (UTC safe).
     * @param dt Datetime to convert into a CRON expression.
     * @return CRON expression as String.
     */
    public static String buildCron(Datetime dt) {
        return String.format(
            '{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month()),
                String.valueOf(dt.year())
            }
        );
    }

    /**
     * @description Generates a short MD5-based hash from a given input string.
     * @param input String to hash.
     * @return First 18 characters of MD5 hash in hex.
     */
    public static String generateMd5Short(String input) {
        Blob hash = Crypto.generateDigest('MD5', Blob.valueOf(input));
        return EncodingUtil.convertToHex(hash).substring(0, 18);
    }

    /**
     * @description Replaces top-level keys in a pretty-printed JSON body with new values.
     * @param body Original JSON string.
     * @param replacements Map of original keys to new keys.
     * @return Modified JSON string with replaced keys.
     */
    public static String patchJsonKeys(String body, Map<String, String> replacements) {
        String formatted = JSON.serializePretty(JSON.deserializeUntyped(body));
        for (String key : replacements.keySet()) {
            formatted = formatted.replaceAll(
                '(?m)^\\s*"' + key + '"\\s*:',
                '"' + replacements.get(key) + '" :'
            );
        }
        return formatted;
    }

    /**
     * @description Parses an ISO-formatted date string into a GMT Datetime.
     * @param iso ISO date string (e.g., "2024-06-01T14:00:00Z").
     * @return Parsed Datetime in GMT.
     */
    public static Datetime parseIso(String iso) {
        return Datetime.valueOfGmt(iso.replace('T', ' ').replace('Z', ''));
    }
}