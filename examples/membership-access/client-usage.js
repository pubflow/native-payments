/**
 * Client-side Usage Examples
 * 
 * This file demonstrates how to use the membership API from the client side
 * to check feature access and handle access control in your application.
 */

// Example using React hooks
import { useState, useEffect, useContext } from 'react';
import { AuthContext } from './auth-context'; // Assuming you have an auth context

/**
 * Custom hook to check if the current user has access to a specific feature
 * @param {string} featureId - The ID of the feature to check
 * @returns {Object} Object containing access status and related data
 */
export function useFeatureAccess(featureId) {
  const { user } = useContext(AuthContext);
  const [accessData, setAccessData] = useState({
    isLoading: true,
    hasAccess: false,
    accessSource: null,
    membership: null,
    addon: null,
    upgradeOptions: [],
    addonOptions: []
  });
  
  useEffect(() => {
    // Don't check if user is not logged in
    if (!user || !user.id) {
      setAccessData({
        isLoading: false,
        hasAccess: false,
        reason: 'Not logged in'
      });
      return;
    }
    
    async function checkAccess() {
      try {
        const response = await fetch(
          `/api/payment/features/check?user_id=${user.id}&feature_id=${featureId}`,
          {
            headers: {
              'Authorization': `Bearer ${user.token}`
            }
          }
        );
        
        const data = await response.json();
        
        setAccessData({
          isLoading: false,
          hasAccess: data.has_access,
          accessSource: data.access_source,
          membership: data.membership,
          addon: data.addon,
          upgradeOptions: data.upgrade_options || [],
          addonOptions: data.addon_options || [],
          reason: data.reason
        });
      } catch (error) {
        console.error('Error checking feature access:', error);
        setAccessData({
          isLoading: false,
          hasAccess: false,
          error: 'Failed to check access'
        });
      }
    }
    
    checkAccess();
  }, [user, featureId]);
  
  return accessData;
}

/**
 * Custom hook to check if the current user has an active membership
 * @param {string} membershipTypeId - Optional specific membership type to check
 * @returns {Object} Object containing membership status and related data
 */
export function useMembershipStatus(membershipTypeId = null) {
  const { user } = useContext(AuthContext);
  const [membershipData, setMembershipData] = useState({
    isLoading: true,
    hasActiveMembership: false,
    memberships: [],
    availableMemberships: []
  });
  
  useEffect(() => {
    // Don't check if user is not logged in
    if (!user || !user.id) {
      setMembershipData({
        isLoading: false,
        hasActiveMembership: false,
        reason: 'Not logged in'
      });
      return;
    }
    
    async function checkMembership() {
      try {
        let url = `/api/payment/memberships/check?user_id=${user.id}`;
        if (membershipTypeId) {
          url += `&membership_type_id=${membershipTypeId}`;
        }
        
        const response = await fetch(url, {
          headers: {
            'Authorization': `Bearer ${user.token}`
          }
        });
        
        const data = await response.json();
        
        setMembershipData({
          isLoading: false,
          hasActiveMembership: data.has_active_membership,
          memberships: data.memberships || [],
          availableMemberships: data.available_memberships || []
        });
      } catch (error) {
        console.error('Error checking membership status:', error);
        setMembershipData({
          isLoading: false,
          hasActiveMembership: false,
          error: 'Failed to check membership'
        });
      }
    }
    
    checkMembership();
  }, [user, membershipTypeId]);
  
  return membershipData;
}

/**
 * Component that conditionally renders content based on feature access
 */
export function FeatureGated({ featureId, children, fallback }) {
  const { isLoading, hasAccess, upgradeOptions, addonOptions } = useFeatureAccess(featureId);
  
  if (isLoading) {
    return <div className="loading">Loading...</div>;
  }
  
  if (!hasAccess) {
    return fallback || (
      <div className="access-denied">
        <h3>Premium Feature</h3>
        <p>This feature requires a premium membership or addon.</p>
        
        {upgradeOptions.length > 0 && (
          <div className="upgrade-options">
            <h4>Upgrade your membership</h4>
            <ul>
              {upgradeOptions.map(option => (
                <li key={option.id}>
                  <button onClick={() => handleUpgrade(option.id)}>
                    {option.name} - {(option.price_cents / 100).toFixed(2)} {option.currency}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
        
        {addonOptions.length > 0 && (
          <div className="addon-options">
            <h4>Purchase as addon</h4>
            <ul>
              {addonOptions.map(option => (
                <li key={option.id}>
                  <button onClick={() => handleAddonPurchase(option.id)}>
                    {option.name} - {(option.price_cents / 100).toFixed(2)} {option.currency}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    );
  }
  
  return children;
}

/**
 * Example usage in a component
 */
function VideoPlayer({ videoId }) {
  const [quality, setQuality] = useState('standard');
  const { hasAccess: hasHDAccess } = useFeatureAccess('hd');
  const { hasAccess: has4KAccess } = useFeatureAccess('4k');
  
  // Available qualities based on access
  const availableQualities = [
    { id: 'standard', label: 'Standard' },
    ...(hasHDAccess ? [{ id: 'hd', label: 'HD' }] : []),
    ...(has4KAccess ? [{ id: '4k', label: '4K' }] : [])
  ];
  
  // Function to get video stream URL based on quality
  async function getVideoStreamUrl(videoId, quality) {
    const response = await fetch(`/api/videos/${videoId}/${quality}`);
    const data = await response.json();
    return data.stream_url;
  }
  
  return (
    <div className="video-player">
      <video controls src={getVideoStreamUrl(videoId, quality)} />
      
      <div className="quality-selector">
        <label>Quality:</label>
        <select 
          value={quality} 
          onChange={(e) => setQuality(e.target.value)}
        >
          {availableQualities.map(q => (
            <option key={q.id} value={q.id}>{q.label}</option>
          ))}
        </select>
      </div>
      
      {!has4KAccess && (
        <FeatureGated featureId="4k">
          <div className="premium-badge">4K Available</div>
        </FeatureGated>
      )}
    </div>
  );
}

/**
 * Example of a user profile component showing membership status
 */
function UserProfile() {
  const { memberships, hasActiveMembership, availableMemberships } = useMembershipStatus();
  
  if (!hasActiveMembership) {
    return (
      <div className="user-profile">
        <h2>No Active Membership</h2>
        <p>You don't have an active membership. Choose a plan to get started:</p>
        
        <div className="membership-options">
          {availableMemberships.map(membership => (
            <div key={membership.id} className="membership-card">
              <h3>{membership.name}</h3>
              <p>{membership.description}</p>
              <p className="price">
                ${(membership.price_cents / 100).toFixed(2)} {membership.currency}
                {membership.duration_type === 'recurring' && 
                  `/${membership.duration_days === 30 ? 'month' : 'year'}`
                }
              </p>
              <button onClick={() => handlePurchaseMembership(membership.id)}>
                Subscribe Now
              </button>
            </div>
          ))}
        </div>
      </div>
    );
  }
  
  return (
    <div className="user-profile">
      <h2>Your Membership</h2>
      
      {memberships.map(membership => (
        <div key={membership.id} className="membership-details">
          <h3>{membership.membership_type.name}</h3>
          <p>Status: {membership.status}</p>
          <p>
            {membership.is_lifetime 
              ? 'Lifetime Access' 
              : `Expires: ${new Date(membership.end_date).toLocaleDateString()}`
            }
          </p>
          
          <h4>Included Features:</h4>
          <ul className="feature-list">
            {JSON.parse(membership.membership_type.features || '[]').map(featureId => (
              <li key={featureId}>{featureId}</li>
            ))}
          </ul>
          
          {membership.addons && JSON.parse(membership.addons).length > 0 && (
            <>
              <h4>Your Addons:</h4>
              <ul className="addon-list">
                {JSON.parse(membership.addons).map(addon => (
                  <li key={addon.feature_id}>
                    {addon.name}
                    {addon.end_date && 
                      ` (Expires: ${new Date(addon.end_date).toLocaleDateString()})`
                    }
                  </li>
                ))}
              </ul>
            </>
          )}
          
          {!membership.is_lifetime && (
            <button onClick={() => handleCancelMembership(membership.id)}>
              Cancel Membership
            </button>
          )}
        </div>
      ))}
    </div>
  );
}
